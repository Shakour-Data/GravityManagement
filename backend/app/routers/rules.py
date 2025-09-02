from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from ..database import get_database
from ..models.rule import Rule, RuleCreate, RuleUpdate
from ..models.user import User
from ..routers.auth import get_current_user

router = APIRouter()

@router.post("/", response_model=Rule)
async def create_rule(rule: RuleCreate, current_user: User = Depends(get_current_user)):
    db = get_database()

    # If project_id is specified, check if user has access to that project
    if rule.project_id:
        project = await db.projects.find_one({
            "_id": rule.project_id,
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Project not found or not authorized")

    rule_dict = rule.dict()
    rule_dict["created_by"] = current_user.username
    result = await db.rules.insert_one(rule_dict)
    created_rule = await db.rules.find_one({"_id": result.inserted_id})
    return Rule(**created_rule)

@router.get("/", response_model=List[Rule])
async def get_rules(project_id: str = None, current_user: User = Depends(get_current_user)):
    db = get_database()
    query = {}

    if project_id:
        # Check project access
        project = await db.projects.find_one({
            "_id": project_id,
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Project not found or not authorized")
        query["project_id"] = project_id
    else:
        # Get rules from user's projects or global rules
        user_projects = await db.projects.find({
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        }).to_list(length=None)
        project_ids = [p["_id"] for p in user_projects]
        query["$or"] = [
            {"project_id": {"$in": project_ids}},
            {"project_id": None},  # Global rules
            {"created_by": current_user.username}  # Rules created by user
        ]

    rules = await db.rules.find(query).to_list(length=None)
    return [Rule(**rule) for rule in rules]

@router.get("/{rule_id}", response_model=Rule)
async def get_rule(rule_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    rule = await db.rules.find_one({"_id": rule_id})
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    # Check if user has access to the rule
    if rule.get("project_id"):
        project = await db.projects.find_one({
            "_id": rule["project_id"],
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Not authorized")
    elif rule.get("created_by") != current_user.username:
        raise HTTPException(status_code=404, detail="Not authorized")

    return Rule(**rule)

@router.put("/{rule_id}", response_model=Rule)
async def update_rule(rule_id: str, rule_update: RuleUpdate, current_user: User = Depends(get_current_user)):
    db = get_database()
    rule = await db.rules.find_one({"_id": rule_id})
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    # Check if user has access to the rule
    if rule.get("project_id"):
        project = await db.projects.find_one({
            "_id": rule["project_id"],
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Not authorized")
    elif rule.get("created_by") != current_user.username:
        raise HTTPException(status_code=404, detail="Not authorized")

    update_data = {k: v for k, v in rule_update.dict().items() if v is not None}
    update_data["updated_at"] = datetime.utcnow()

    await db.rules.update_one({"_id": rule_id}, {"$set": update_data})
    updated_rule = await db.rules.find_one({"_id": rule_id})
    return Rule(**updated_rule)

@router.delete("/{rule_id}")
async def delete_rule(rule_id: str, current_user: User = Depends(get_current_user)):
    db = get_database()
    rule = await db.rules.find_one({"_id": rule_id})
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    # Check if user has access to the rule
    if rule.get("project_id"):
        project = await db.projects.find_one({
            "_id": rule["project_id"],
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Not authorized")
    elif rule.get("created_by") != current_user.username:
        raise HTTPException(status_code=404, detail="Not authorized")

    await db.rules.delete_one({"_id": rule_id})
    return {"message": "Rule deleted successfully"}

@router.post("/{rule_id}/test")
async def test_rule(rule_id: str, test_data: dict, current_user: User = Depends(get_current_user)):
    """
    Test a rule with sample data without executing actions
    """
    db = get_database()
    rule = await db.rules.find_one({"_id": rule_id})
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    # Check if user has access to the rule
    if rule.get("project_id"):
        project = await db.projects.find_one({
            "_id": rule["project_id"],
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Not authorized")
    elif rule.get("created_by") != current_user.username:
        raise HTTPException(status_code=404, detail="Not authorized")

    from ..services.rule_engine import rule_engine

    # Test condition evaluation
    conditions_met = rule_engine._check_conditions(rule["conditions"], test_data)

    return {
        "rule_id": rule_id,
        "conditions_met": conditions_met,
        "test_data": test_data,
        "rule_conditions": rule["conditions"]
    }

@router.post("/{rule_id}/trigger")
async def trigger_rule(rule_id: str, event_data: dict, current_user: User = Depends(get_current_user)):
    """
    Manually trigger a rule by ID with event data
    """
    db = get_database()
    rule = await db.rules.find_one({"_id": rule_id, "active": True})
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found or inactive")

    # Check if user has access to the rule
    if rule.get("project_id"):
        project = await db.projects.find_one({
            "_id": rule["project_id"],
            "$or": [{"owner_id": current_user.username}, {"team_members": current_user.username}]
        })
        if not project:
            raise HTTPException(status_code=404, detail="Not authorized")
    elif rule.get("created_by") != current_user.username:
        raise HTTPException(status_code=404, detail="Not authorized")

    from ..services.rule_engine import rule_engine

    triggered_actions = await rule_engine.trigger_rule_manually(rule_id, event_data)

    return {
        "rule_id": rule_id,
        "triggered_actions": triggered_actions
    }
