import os
import json
import logging
import boto3
from kafka import KafkaProducer
from kafka.errors import KafkaError
# === 1. AbstractTokenProvider를 import 합니다. ===
from kafka.sasl.oauth import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
from datetime import datetime 

# --- 로깅 설정 ---
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# --- 상수 및 환경 변수 ---
REGION = os.environ.get('AWS_REGION', 'us-east-1')
CLUSTER_ARN = os.environ.get('MSK_CLUSTER_ARN')
TOPIC = os.environ.get('MSK_TOPIC', 'fanda-notifications')

# === 2. AbstractTokenProvider를 상속받도록 클래스를 수정합니다. ===
class MSKTokenProvider(AbstractTokenProvider):
    def __init__(self, region: str):
        self.region = region

    def token(self) -> str:
        """
        kafka-python 라이브러리가 인증 토큰을 필요로 할 때마다 이 메서드를 호출합니다.
        자동으로 새 토큰을 생성하여 반환하므로 토큰 만료를 걱정할 필요가 없습니다.
        """
        token, _ = MSKAuthTokenProvider.generate_auth_token(self.region)
        logger.info("Successfully generated new MSK IAM Auth Token for Producer.")
        return token

# --- Kafka Producer 초기화를 위한 전역 변수 ---
producer = None

def get_kafka_producer():
    """
    전역 producer 인스턴스를 관리하는 함수 (싱글톤 패턴).
    Lambda가 재사용될 때마다 새로 생성하지 않도록 합니다.
    """
    global producer
    if producer:
        logger.info("Reusing existing Kafka producer instance.")
        return producer

    if not CLUSTER_ARN:
        raise ValueError("MSK_CLUSTER_ARN environment variable is not set")

    logger.info("Initializing Kafka producer for the first time (cold start)...")
    try:
        # 1. 부트스트랩 브로커 동적 조회
        kafka_client = boto3.client('kafka', region_name=REGION)
        bootstrap_info = kafka_client.get_bootstrap_brokers(ClusterArn=CLUSTER_ARN)
        bootstrap_servers = bootstrap_info['BootstrapBrokerStringSaslIam']
        logger.info(f"Dynamically fetched bootstrap servers: {bootstrap_servers}")

        # 2. 동적 토큰 제공자 인스턴스 생성
        token_provider = MSKTokenProvider(region=REGION)

        # 3. Kafka Producer 초기화 (변경 없음)
        producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            security_protocol='SASL_SSL',
            sasl_mechanism='OAUTHBEARER',
            sasl_oauth_token_provider=token_provider,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            retries=5,
            request_timeout_ms=30000
        )
        logger.info("Kafka producer initialized successfully.")
        return producer
    except Exception as e:
        logger.error(f"Failed to create Kafka producer: {e}", exc_info=True)
        raise

# --- Lambda 핸들러 함수 ---
def lambda_handler(event, context):
    try:
        kafka_producer = get_kafka_producer()
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps(f'Failed to initialize Kafka Producer: {str(e)}')}

    records = event.get('Records', [])
    logger.info(f"Received {len(records)} S3 records to process.")

    for record in records:
        try:
            s3_info = record.get('s3', {})
            bucket = s3_info.get('bucket', {}).get('name')
            key = s3_info.get('object', {}).get('key')
            if not bucket or not key:
                logger.warning(f"Skipping record due to missing bucket or key: {record}")
                continue

            # os.path.basename을 사용해 전체 경로(key)에서 파일 이름만 추출합니다.
            clean_filename = os.path.basename(key)  
            upload_time = record.get('eventTime')
            version_from_upload = "N/A" # 기본값
            if upload_time:
                try:
                    dt_object = datetime.fromisoformat(upload_time.replace('Z', '+00:00'))
                    version_from_upload = dt_object.strftime('%y.%m.%d')
                except (ValueError, TypeError):
                    version_from_upload = upload_time.split('T')[0]

            #  category 결정 로직
            category = "general" # 기본값
            if key.startswith("reports/positive/"):
                category = "positive"
            elif key.startswith("reports/negative/"):
                category = "negative"
            elif key.startswith("reports/feedback/"):
                category = "feedback"


            message = {
                'fileName': clean_filename,
                'bucketName': bucket,
                'fileSize': s3_info.get('object', {}).get('size'),
                'uploadTime': record.get('eventTime'),
                'version': version_from_upload,
                's3Url': f"s3://{bucket}/{key}",
                "category": category   # 👈 컨슈머가 이 값을 활용합니다
            }

            

            future = kafka_producer.send(TOPIC, message)
            result = future.get(timeout=10)
            logger.info(f"Message sent to topic={result.topic} partition={result.partition} offset={result.offset}")

        except KafkaError as e:
            logger.error(f"Failed to send message to Kafka for object {key}: {e}")
        except Exception as e:
            logger.error(f"An unexpected error occurred while processing record for object {key}: {e}", exc_info=True)

    kafka_producer.flush()

    return {
        'statusCode': 200,
        'body': json.dumps('Finished processing S3 events successfully.')
    }
