# # lambda_function.py

# import boto3
# import os
# import time
# import logging

# # 로깅 설정
# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# # 환경 변수에서 Distribution ID 가져오기
# CLOUDFRONT_DISTRIBUTION_ID = os.environ.get('CLOUDFRONT_DISTRIBUTION_ID')

# cloudfront_client = boto3.client('cloudfront')

# def lambda_handler(event, context):
#     if not CLOUDFRONT_DISTRIBUTION_ID:
#         logger.error("CLOUDFRONT_DISTRIBUTION_ID environment variable not set.")
#         return

#     logger.info("S3 event received: %s", json.dumps(event))

#     paths_to_invalidate = []
#     for record in event.get('Records', []):
#         s3_object_key = record.get('s3', {}).get('object', {}).get('key')

#         if s3_object_key:
#             # CloudFront 무효화 경로는 반드시 '/'로 시작해야 합니다.
#             # URL 인코딩된 문자를 디코딩할 필요가 있을 수 있습니다 (예: 공백이 '+'로 변환).
#             import urllib.parse
#             decoded_key = urllib.parse.unquote_plus(s3_object_key)
#             invalidation_path = '/' + decoded_key
#             paths_to_invalidate.append(invalidation_path)
    
#     if not paths_to_invalidate:
#         logger.info("No paths to invalidate from the event.")
#         return

#     caller_reference = str(int(time.time()))
#     logger.info("Creating invalidation for paths: %s with reference: %s", paths_to_invalidate, caller_reference)
    
#     try:
#         response = cloudfront_client.create_invalidation(
#             DistributionId=CLOUDFRONT_DISTRIBUTION_ID,
#             InvalidationBatch={
#                 'Paths': {
#                     'Quantity': len(paths_to_invalidate),
#                     'Items': paths_to_invalidate
#                 },
#                 'CallerReference': caller_reference
#             }
#         )
#         logger.info("Successfully created CloudFront invalidation request: %s", response)
#         return {
#             'statusCode': 200,
#             'body': 'CloudFront invalidation request created successfully.'
#         }
#     except Exception as e:
#         logger.error("Error creating CloudFront invalidation: %s", str(e))
#         raise e