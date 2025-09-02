from typing import Dict, Any, List
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
from datetime import datetime
from ..database import get_database

class NotificationService:
    def __init__(self):
        self.db = get_database()
        self.smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_username = os.getenv("SMTP_USERNAME", "")
        self.smtp_password = os.getenv("SMTP_PASSWORD", "")
        self.from_email = os.getenv("FROM_EMAIL", "noreply@gravitypm.com")

    async def send_email(self, to_email: str, subject: str, body: str, template_name: str = None) -> Dict[str, Any]:
        """
        Send an email notification
        """
        if not self.smtp_username or not self.smtp_password:
            # Fallback: log the notification instead of sending
            await self._log_notification(to_email, subject, body, "email", template_name)
            return {"message": "Email logged (SMTP not configured)", "sent": False}

        try:
            msg = MIMEMultipart()
            msg['From'] = self.from_email
            msg['To'] = to_email
            msg['Subject'] = subject

            msg.attach(MIMEText(body, 'html'))

            server = smtplib.SMTP(self.smtp_server, self.smtp_port)
            server.starttls()
            server.login(self.smtp_username, self.smtp_password)
            text = msg.as_string()
            server.sendmail(self.from_email, to_email, text)
            server.quit()

            await self._log_notification(to_email, subject, body, "email", template_name, True)
            return {"message": "Email sent successfully", "sent": True}

        except Exception as e:
            await self._log_notification(to_email, subject, body, "email", template_name, False, str(e))
            return {"error": f"Failed to send email: {str(e)}", "sent": False}

    async def send_notification(self, recipient: str, notification_type: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send a notification based on type and data
        """
        if notification_type == "email":
            template = self._get_email_template(data.get("template", "default"))
            subject = template["subject"].format(**data)
            body = template["body"].format(**data)
            return await self.send_email(recipient, subject, body, data.get("template"))
        elif notification_type == "in_app":
            return await self._send_in_app_notification(recipient, data)
        else:
            return {"error": f"Unsupported notification type: {notification_type}"}

    def _get_email_template(self, template_name: str) -> Dict[str, str]:
        """
        Get email template by name
        """
        templates = {
            "default": {
                "subject": "Notification from GravityPM",
                "body": """
                <html>
                <body>
                    <h2>GravityPM Notification</h2>
                    <p>{message}</p>
                    <p>Best regards,<br>GravityPM Team</p>
                </body>
                </html>
                """
            },
            "task_assigned": {
                "subject": "New Task Assigned: {task_title}",
                "body": """
                <html>
                <body>
                    <h2>New Task Assigned</h2>
                    <p>You have been assigned a new task:</p>
                    <p><strong>{task_title}</strong></p>
                    <p>Description: {task_description}</p>
                    <p>Due Date: {due_date}</p>
                    <p>Project: {project_name}</p>
                    <p>Please check your dashboard for more details.</p>
                    <p>Best regards,<br>GravityPM Team</p>
                </body>
                </html>
                """
            },
            "budget_alert": {
                "subject": "Budget Alert for Project: {project_name}",
                "body": """
                <html>
                <body>
                    <h2>Budget Alert</h2>
                    <p>Warning: The project <strong>{project_name}</strong> has exceeded {threshold_percentage}% of its budget.</p>
                    <p>Current spending: ${spent_amount}</p>
                    <p>Budget: ${budget_amount}</p>
                    <p>Remaining: ${remaining_amount}</p>
                    <p>Please review the project expenses.</p>
                    <p>Best regards,<br>GravityPM Team</p>
                </body>
                </html>
                """
            },
            "rule_triggered": {
                "subject": "Rule Triggered: {rule_name}",
                "body": """
                <html>
                <body>
                    <h2>Rule Triggered</h2>
                    <p>The rule <strong>{rule_name}</strong> has been triggered.</p>
                    <p>Event: {event_type}</p>
                    <p>Actions taken: {actions_summary}</p>
                    <p>Please check the system for more details.</p>
                    <p>Best regards,<br>GravityPM Team</p>
                </body>
                </html>
                """
            }
        }
        return templates.get(template_name, templates["default"])

    async def _send_in_app_notification(self, recipient: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Send an in-app notification
        """
        notification = {
            "recipient": recipient,
            "type": "in_app",
            "title": data.get("title", "Notification"),
            "message": data.get("message", ""),
            "data": data,
            "read": False,
            "created_at": datetime.utcnow()
        }

        await self.db.notifications.insert_one(notification)
        return {"message": "In-app notification sent", "sent": True}

    async def _log_notification(self, recipient: str, subject: str, body: str, notification_type: str,
                               template_name: str = None, sent: bool = False, error: str = None):
        """
        Log notification for tracking
        """
        log_entry = {
            "recipient": recipient,
            "subject": subject,
            "body": body,
            "type": notification_type,
            "template": template_name,
            "sent": sent,
            "error": error,
            "created_at": datetime.utcnow()
        }

        await self.db.notification_logs.insert_one(log_entry)

    async def get_user_notifications(self, user_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get notifications for a user
        """
        notifications = await self.db.notifications.find(
            {"recipient": user_id}
        ).sort("created_at", -1).limit(limit).to_list(length=None)

        return notifications

    async def mark_notification_read(self, notification_id: str, user_id: str) -> bool:
        """
        Mark a notification as read
        """
        result = await self.db.notifications.update_one(
            {"_id": notification_id, "recipient": user_id},
            {"$set": {"read": True, "read_at": datetime.utcnow()}}
        )
        return result.modified_count > 0

notification_service = NotificationService()
