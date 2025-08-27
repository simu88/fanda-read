import os
import json # json 라이브러리 import가 필요합니다.
import logging
from typing import Dict, Any
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

logger = logging.getLogger(__name__)

class SlackHandler:
    def __init__(self):
        self.bot_token = os.getenv('SLACK_BOT_TOKEN')
        if not self.bot_token:
            raise ValueError("SLACK_BOT_TOKEN environment variable is required")

        self.client = WebClient(token=self.bot_token)

        # 환경 변수에서 JSON 문자열을 읽어 Python 딕셔너리로 파싱 
        channel_map_json = os.getenv("SLACK_CHANNEL_MAP")
        if channel_map_json:
            try:
                self.channel_map = json.loads(channel_map_json)
                logger.info(f"Slack channel map loaded from env: {self.channel_map}")
            except json.JSONDecodeError:
                logger.error("Failed to parse SLACK_CHANNEL_MAP JSON. Using default.")
                self.channel_map = {"general": "#general"} # 파싱 실패 시 비상용
        else:
            logger.warning("SLACK_CHANNEL_MAP not set. Using default.")
            self.channel_map = {"general": "#general"}

    def send_notification(self, message: Dict[str, Any]) -> None:
        # 1. 메시지에서 'category'를 가져옵니다. 없으면 'general'을 기본값으로 사용합니다.
        category = message.get("category", "general")

        # 2. self.channel_map에서 category에 해당하는 채널을 찾습니다.
        #    만약 category 키가 없다면, 'general' 키의 채널을 사용합니다.
        target_channel = self.channel_map.get(category, self.channel_map.get("general"))

        # 3. 채널을 찾지 못한 경우 에러를 기록하고 함수를 종료합니다.
        if not target_channel:
            logger.error(f"No Slack channel found for category '{category}' or default. Cannot send message.")
            return
        
        try:
            #blocks = self._format_message(message)
            blocks = self._format_message(message, category)
            response = self.client.chat_postMessage(channel=target_channel, blocks=blocks, text=f"New report uploaded: {message.get('fileName')}")
            # 로그에 어떤 채널로 보냈는지 명시해줍니다.
            logger.info(f"Slack message sent successfully to channel '{target_channel}': {response['ts']}")
        except SlackApiError as e:
            logger.error(f"Slack API error sending to channel '{target_channel}': {e.response['error']}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error sending Slack message to channel '{target_channel}': {e}")
            raise

    def _format_message(self, message: Dict[str, Any], category: str) -> list:
        file_name = message.get('fileName', 'Unknown file')
        file_size = message.get('fileSize', 'Unknown size')
        upload_time = message.get('uploadTime', 'Unknown time')
        view_url = message.get('httpUrl', message.get('s3Url', ''))
        version = message.get("version", "Unknown version")
        

        # blocks = [
        #     {"type": "header", "text": {"type": "plain_text", "text": "New File Uploaded to S3"}},
        #     {"type": "section", "fields": [
        #         {"type": "mrkdwn", "text": f"*File Name:*\n{file_name}"},
        #         {"type": "mrkdwn", "text": f"*Bucket:*\n{bucket_name}"},
        #         {"type": "mrkdwn", "text": f"*File Size:*\n{file_size}"},
        #         {"type": "mrkdwn", "text": f"*Upload Time:*\n{upload_time}"}
        #     ]}
        # ]


        # 1. Category에 따라 동적으로 헤더 텍스트를 결정합니다.
        header_text = f"💡 신규 파일 업로드 알림_{version}" # 기본값
        if category == "positive":
            header_text = f"💡 긍정 리뷰 분석 보고서_{version}"
        elif category == "negative":
            header_text = f"💡 부정 리뷰 분석 보고서_{version}"
        elif category == "feedback":
            header_text = f"💡 피드백 개선 보고서_{version}"

         # 2. Block Kit 구조를 개선하여 정보 계층을 명확하게 합니다.
        blocks = [
            # 헤더: 무슨 일인지 요약
            {
                "type": "header",
                "text": {"type": "plain_text", "text": header_text}
            },
            # 구분선
            {"type": "divider"},
            # 본문 1: 가장 중요한 정보인 '파일 이름'을 링크와 함께 강조
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    # >는 들여쓰기 효과, <URL|텍스트> 형식으로 링크를 만듭니다.
                    "text": f"*파일명:*\n<{view_url}|{file_name}>"
                }
            },
            # 본문 2: 나머지 메타데이터 정보
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*파일 크기:*\n{file_size} bytes"},
                    {"type": "mrkdwn", "text": f"*업로드 시간:*\n{upload_time}"}
                ]
            }
        ]


        if view_url:
            blocks.append({
                "type": "actions",
                "elements": [{"type": "button", "text": {"type": "plain_text", "text": "View in S3"}, "url": view_url, "style": "primary"}]
            })

        return blocks
