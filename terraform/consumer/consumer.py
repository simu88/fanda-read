import os
import json
import logging
import sys
from typing import Dict, Any

from kafka import KafkaConsumer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

from channels.slack_handler import SlackHandler
from channels.email_handler import EmailHandler  # 필요 시 활성화

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# MSK IAM 인증 토큰을 동적으로 제공하는 클래스 (AWS 공식 문서 방식)
class MSKTokenProvider:
    def __init__(self, region: str):
        self.region = region

    def token(self) -> str:
        """
        kafka-python 라이브러리가 인증 토큰을 필요로 할 때마다 이 메서드를 호출합니다.
        자동으로 새 토큰을 생성하여 반환하므로 토큰 만료를 걱정할 필요가 없습니다.
        """
        token, _ = MSKAuthTokenProvider.generate_auth_token(self.region)
        logger.info("Successfully generated new MSK IAM Auth Token.")
        return token


class KafkaToChannelsService:
    def __init__(self):
        # 환경변수 읽기
        self.kafka_bootstrap_servers = os.getenv('MSK_BOOTSTRAP_SERVERS')
        self.kafka_topics = os.getenv('MSK_TOPIC', 'fanda-notifications').split(",")
        self.kafka_group_id = os.getenv('MSK_CONSUMER_GROUP', 'msk-consumer-group')
        self.region = os.getenv('AWS_REGION', 'us-east-1')

        # Kafka Consumer 생성
        self.consumer = self._create_kafka_consumer()

        # 채널 핸들러 초기화
        self.handlers = {}
        enabled_channels = os.getenv('ENABLED_CHANNELS', 'slack,email').split(',')
        if 'slack' in enabled_channels:
            self.handlers['slack'] = SlackHandler()
        if 'email' in enabled_channels:
            self.handlers['email'] = EmailHandler()

        logger.info("Kafka to Channels service initialized")
        logger.info(f"Enabled channels: {list(self.handlers.keys())}")

    def _create_kafka_consumer(self) -> KafkaConsumer:
        try:
            # 동적 토큰 제공자 인스턴스 생성
            token_provider = MSKTokenProvider(region=self.region)

            consumer = KafkaConsumer(
                *self.kafka_topics,
                bootstrap_servers=self.kafka_bootstrap_servers,
                security_protocol='SASL_SSL',
                # Python 클라이언트는 OAUTHBEARER 메커니즘을 사용합니다.
                sasl_mechanism='OAUTHBEARER',
                # 정적 비밀번호 대신 동적 토큰 제공자를 지정합니다.
                sasl_oauth_token_provider=token_provider,
                group_id=self.kafka_group_id,
                auto_offset_reset='earliest',
                enable_auto_commit=True,
                value_deserializer=lambda x: json.loads(x.decode('utf-8')),

            )
            logger.info(f"Kafka consumer subscribed to topics: {self.kafka_topics}")
            return consumer
        except Exception as e:
            logger.error(f"Failed to create Kafka consumer: {e}")
            raise

    def _convert_s3_to_http_url(self, s3_url: str) -> str:
        try:
            if s3_url.startswith('s3://'):
                parts = s3_url[5:].split('/', 1)
                bucket_name = parts[0]
                object_key = parts[1] if len(parts) > 1 else ""
                return f"https://{bucket_name}.s3.amazonaws.com/{object_key}"
            return s3_url
        except Exception as e:
            logger.error(f"Error converting S3 URL: {e}")
            return s3_url

    def process_message(self, message: Dict[str, Any]) -> None:
        try:
            if 's3Url' in message:
                message['httpUrl'] = self._convert_s3_to_http_url(message['s3Url'])

            for channel_name, handler in self.handlers.items():
                try:
                    handler.send_notification(message)
                    logger.info(f"Message sent to {channel_name} successfully")
                except Exception as e:
                    logger.error(f"Failed to send message to {channel_name}: {e}")

            self._log_message(message)
        except Exception as e:
            logger.error(f"Error processing message: {e}")

    def _log_message(self, message: Dict[str, Any]) -> None:
        logger.info("=" * 50)
        logger.info(f"File: {message.get('fileName', 'Unknown')}")
        logger.info(f"Bucket: {message.get('bucketName', 'Unknown')}")
        logger.info(f"Size: {message.get('fileSize', 'Unknown')}")
        logger.info(f"Upload Time: {message.get('uploadTime', 'Unknown')}")
        logger.info(f"S3 URL: {message.get('s3Url', 'Unknown')}")
        logger.info(f"HTTP URL: {message.get('httpUrl', 'Unknown')}")
        logger.info("=" * 50)

    def start_consuming(self):
        logger.info("Starting Kafka message consumption...")
        try:
            for message in self.consumer:
                try:
                    self.process_message(message.value)
                except Exception as e:
                    logger.error(f"Error processing individual message: {e}")
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        except Exception as e:
            logger.error(f"Error in main consumption loop: {e}")
        finally:
            self.consumer.close()
            logger.info("Kafka consumer closed")

def main():
    if not os.getenv('MSK_BOOTSTRAP_SERVERS'):
        logger.error("MSK_BOOTSTRAP_SERVERS environment variable is not set")
        sys.exit(1)

    service = KafkaToChannelsService()
    service.start_consuming()

if __name__ == "__main__":
    main()
