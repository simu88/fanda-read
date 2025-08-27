import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Dict, Any

logger = logging.getLogger(__name__)

class EmailHandler:
    def __init__(self):
        self.smtp_server = os.getenv('SMTP_SERVER', 'smtp.gmail.com')
        self.smtp_port = int(os.getenv('SMTP_PORT', 587))
        self.sender_email = os.getenv('EMAIL_SENDER')
        self.sender_password = os.getenv('EMAIL_PASSWORD')
        self.recipient_email = os.getenv('EMAIL_RECIPIENT')

        if not all([self.sender_email, self.sender_password, self.recipient_email]):
            raise ValueError("EMAIL_SENDER, EMAIL_PASSWORD, EMAIL_RECIPIENT environment variables are required")

        logger.info(f"Email handler initialized - sending from {self.sender_email} to {self.recipient_email}")

    def send_notification(self, message: Dict[str, Any]) -> None:
        try:
            email_msg = self._create_email_message(message)
            recipients = [email.strip() for email in self.recipient_email.split(',')]

            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.sender_email, self.sender_password)
                server.sendmail(self.sender_email, recipients, email_msg.as_string())

            logger.info(f"Email notification sent successfully to {len(recipients)} recipients")
        except Exception as e:
            logger.error(f"Failed to send email: {e}")
            raise

    def _create_email_message(self, message: Dict[str, Any]) -> MIMEMultipart:
        file_name = message.get('fileName', 'Unknown file')
        bucket_name = message.get('bucketName', 'Unknown bucket')
        file_size = message.get('fileSize', 'Unknown size')
        upload_time = message.get('uploadTime', 'Unknown time')
        view_url = message.get('httpUrl', message.get('s3Url', ''))

        msg = MIMEMultipart('alternative')
        msg['Subject'] = f"New File Uploaded: {file_name}"
        msg['From'] = self.sender_email
        msg['To'] = self.recipient_email

        html_body = f"""
        <html>
          <body>
            <h2>New File Uploaded to S3</h2>
            <p>File Name: {file_name}<br/>
               Bucket: {bucket_name}<br/>
               File Size: {file_size}<br/>
               Upload Time: {upload_time}</p>
            {f'<a href="{view_url}">View File in S3</a>' if view_url else ''}
          </body>
        </html>
        """
        text_body = f"New File Uploaded to S3\nFile Name: {file_name}\nBucket: {bucket_name}\nFile Size: {file_size}\nUpload Time: {upload_time}\n{f'View File: {view_url}' if view_url else ''}"

        msg.attach(MIMEText(text_body, 'plain'))
        msg.attach(MIMEText(html_body, 'html'))
        return msg
