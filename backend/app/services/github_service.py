from typing import Dict, Any, List
import hmac
import hashlib
from fastapi import HTTPException
from ..services.rule_engine import rule_engine

# GitHub webhook secret - should be set via environment variable
GITHUB_WEBHOOK_SECRET = "your-github-webhook-secret"  # TODO: Use environment variable

def verify_github_signature(payload: bytes, signature: str) -> bool:
    """
    Verify GitHub webhook signature
    """
    if not GITHUB_WEBHOOK_SECRET:
        return True  # Skip verification if no secret is set

    expected_signature = hmac.new(
        GITHUB_WEBHOOK_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(f"sha256={expected_signature}", signature)

async def process_github_webhook(event_type: str, payload: Dict[str, Any], signature: str = None) -> Dict[str, Any]:
    """
    Process GitHub webhook events and trigger rule evaluation
    """
    # Verify signature if provided
    if signature and not verify_github_signature(str(payload).encode(), signature):
        raise HTTPException(status_code=401, detail="Invalid signature")

    print(f"Processing GitHub event: {event_type}")

    # Extract relevant event data
    event_data = extract_event_data(event_type, payload)

    # Evaluate rules for this event
    triggered_actions = await rule_engine.evaluate_rules("github_event", event_data)

    return {
        "event_type": event_type,
        "processed": True,
        "triggered_actions": triggered_actions,
        "event_data": event_data
    }

def extract_event_data(event_type: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Extract relevant data from GitHub webhook payload based on event type
    """
    event_data = {
        "event_type": event_type,
        "repository": payload.get("repository", {}).get("full_name", ""),
        "sender": payload.get("sender", {}).get("login", ""),
        "action": payload.get("action", ""),
    }

    if event_type == "push":
        event_data.update({
            "branch": payload.get("ref", "").replace("refs/heads/", ""),
            "commits": len(payload.get("commits", [])),
            "commit_message": payload.get("head_commit", {}).get("message", "") if payload.get("commits") else "",
            "author": payload.get("head_commit", {}).get("author", {}).get("name", "") if payload.get("commits") else "",
        })

    elif event_type == "pull_request":
        pr = payload.get("pull_request", {})
        event_data.update({
            "pull_request_title": pr.get("title", ""),
            "pull_request_number": pr.get("number"),
            "pull_request_state": pr.get("state", ""),
            "pull_request_body": pr.get("body", ""),
            "base_branch": pr.get("base", {}).get("ref", ""),
            "head_branch": pr.get("head", {}).get("ref", ""),
        })

    elif event_type == "issues":
        issue = payload.get("issue", {})
        event_data.update({
            "issue_title": issue.get("title", ""),
            "issue_number": issue.get("number"),
            "issue_state": issue.get("state", ""),
            "issue_body": issue.get("body", ""),
            "issue_labels": [label["name"] for label in issue.get("labels", [])],
        })

    elif event_type == "issue_comment":
        comment = payload.get("comment", {})
        issue = payload.get("issue", {})
        event_data.update({
            "comment_body": comment.get("body", ""),
            "comment_author": comment.get("user", {}).get("login", ""),
            "issue_title": issue.get("title", ""),
            "issue_number": issue.get("number"),
        })

    elif event_type == "release":
        release = payload.get("release", {})
        event_data.update({
            "release_tag": release.get("tag_name", ""),
            "release_name": release.get("name", ""),
            "release_body": release.get("body", ""),
            "release_prerelease": release.get("prerelease", False),
        })

    return event_data

async def get_github_repos(github_user_id: str) -> List[Dict[str, Any]]:
    """
    Get GitHub repositories for a user
    Note: This is a stub - would need GitHub API integration
    """
    # TODO: Implement actual GitHub API call
    # This would require GitHub API token and proper authentication
    return [
        {
            "id": "repo_1",
            "name": "example-repo",
            "full_name": "user/example-repo",
            "description": "Example repository",
            "private": False,
            "html_url": "https://github.com/user/example-repo",
            "language": "Python",
        }
    ]

async def create_github_issue(repo_full_name: str, title: str, body: str, labels: List[str] = None) -> Dict[str, Any]:
    """
    Create a GitHub issue
    Note: This is a stub - would need GitHub API integration
    """
    # TODO: Implement actual GitHub API call to create issue
    return {
        "number": 123,
        "title": title,
        "body": body,
        "html_url": f"https://github.com/{repo_full_name}/issues/123",
        "state": "open",
        "labels": labels or [],
    }

async def get_github_commits(repo_full_name: str, branch: str = "main", since: str = None) -> List[Dict[str, Any]]:
    """
    Get commits from a GitHub repository
    Note: This is a stub - would need GitHub API integration
    """
    # TODO: Implement actual GitHub API call to get commits
    return [
        {
            "sha": "abc123",
            "message": "Example commit message",
            "author": "example-user",
            "date": "2023-01-01T00:00:00Z",
        }
    ]
