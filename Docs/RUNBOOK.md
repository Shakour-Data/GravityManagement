# GravityPM Production Runbook

## Overview
This runbook provides operational procedures for managing the GravityPM production environment. It includes standard operating procedures, troubleshooting guides, and emergency response protocols.

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Daily Operations](#daily-operations)
3. [Monitoring and Alerting](#monitoring-and-alerting)
4. [Incident Response](#incident-response)
5. [Deployment Procedures](#deployment-procedures)
6. [Backup and Recovery](#backup-and-recovery)
7. [Security Procedures](#security-procedures)
8. [Performance Management](#performance-management)
9. [Maintenance Procedures](#maintenance-procedures)
10. [Emergency Contacts](#emergency-contacts)

## System Architecture

### Core Components
- **Frontend**: React.js application served by Nginx
- **Backend**: Node.js/Express API server
- **Database**: MongoDB with replica set
- **Cache**: Redis cluster
- **Load Balancer**: Nginx with SSL termination
- **Monitoring**: Prometheus + Grafana + ELK Stack
- **Security**: WAF, OAuth 2.0, MFA

### Infrastructure
- **Cloud Provider**: AWS
- **Region**: us-east-1
- **VPC**: gravitypm-production
- **Subnets**: Public and private subnets across 3 AZs
- **Auto Scaling**: ECS with CPU/memory based scaling

## Daily Operations

### Morning Checklist
1. **Check System Health**
   ```bash
   # Check all services
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml ps

   # Check monitoring dashboards
   open http://monitoring.gravitypm.com
   ```

2. **Review Overnight Metrics**
   - Check error rates (< 1%)
   - Review performance metrics
   - Verify backup completion
   - Check security alerts

3. **Validate Core Functionality**
   ```bash
   # Test application endpoints
   curl -f https://api.gravitypm.com/health
   curl -f https://gravitypm.com/
   ```

### Evening Checklist
1. **Backup Verification**
   ```bash
   # Check backup logs
   tail -f /opt/gravitypm/production/logs/backup.log
   ```

2. **Resource Usage Review**
   - Check disk space (> 20% free)
   - Monitor memory usage
   - Review CPU utilization

3. **Security Review**
   - Check failed login attempts
   - Review access logs
   - Verify SSL certificate validity

## Monitoring and Alerting

### Key Metrics to Monitor

#### Application Metrics
- **Response Time**: < 500ms (95th percentile)
- **Error Rate**: < 1%
- **Throughput**: 100-1000 req/sec
- **Availability**: > 99.9%

#### System Metrics
- **CPU Usage**: < 80%
- **Memory Usage**: < 85%
- **Disk Usage**: < 80%
- **Network I/O**: Monitor for spikes

#### Database Metrics
- **Connection Count**: < 80% of max
- **Query Response Time**: < 100ms
- **Replication Lag**: < 30 seconds
- **Lock Wait Time**: < 5 seconds

### Alert Categories

#### Critical Alerts (Immediate Response)
- Service down/unavailable
- Database connection failure
- Security breach detected
- Data loss/corruption
- Certificate expiration (< 30 days)

#### Warning Alerts (Response within 1 hour)
- High resource usage (> 90%)
- Increased error rates (> 5%)
- Performance degradation
- Backup failures

#### Info Alerts (Monitor)
- Maintenance notifications
- Configuration changes
- User activity spikes

### Alert Response Procedures

#### Service Down Alert
1. **Immediate Assessment**
   ```bash
   # Check service status
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml ps

   # Check logs
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml logs --tail=100 <service>
   ```

2. **Restart Service**
   ```bash
   # Restart specific service
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml restart <service>
   ```

3. **Escalation**
   - If restart fails, escalate to on-call engineer
   - Notify stakeholders if downtime > 5 minutes

#### High Error Rate Alert
1. **Investigate Logs**
   ```bash
   # Check application logs
   tail -f /opt/gravitypm/production/logs/app.log | grep ERROR

   # Check nginx error logs
   tail -f /var/log/nginx/error.log
   ```

2. **Identify Root Cause**
   - Database connection issues
   - Memory/CPU exhaustion
   - Network connectivity problems
   - Code deployment issues

3. **Resolution**
   - Roll back deployment if needed
   - Scale resources if required
   - Fix configuration issues

## Incident Response

### Incident Classification

#### Severity 1 (Critical)
- Complete system outage
- Data loss or corruption
- Security breach
- **Response Time**: Immediate
- **Resolution Time**: < 1 hour

#### Severity 2 (High)
- Major functionality impacted
- Performance severely degraded
- **Response Time**: < 15 minutes
- **Resolution Time**: < 4 hours

#### Severity 3 (Medium)
- Minor functionality issues
- Performance moderately impacted
- **Response Time**: < 1 hour
- **Resolution Time**: < 24 hours

#### Severity 4 (Low)
- Cosmetic issues
- Minor performance issues
- **Response Time**: < 4 hours
- **Resolution Time**: < 72 hours

### Incident Response Process

#### 1. Detection
- Automated monitoring alerts
- User reports
- System logs

#### 2. Assessment
```bash
# Gather system information
date
uptime
df -h
free -h
docker stats
```

#### 3. Containment
- Isolate affected components
- Implement temporary fixes
- Communicate with stakeholders

#### 4. Resolution
- Identify root cause
- Implement permanent fix
- Test fix in staging
- Deploy to production

#### 5. Post-Mortem
- Document incident
- Identify improvements
- Update procedures
- Train team members

### Communication Protocol

#### Internal Communication
- Use Slack channel: #incidents
- Update incident status every 30 minutes
- Notify management for Sev 1/2 incidents

#### External Communication
- Use status page: status.gravitypm.com
- Notify customers for Sev 1 incidents
- Provide regular updates

## Deployment Procedures

### Standard Deployment
1. **Pre-Deployment Checks**
   ```bash
   # Run tests
   npm test
   npm run e2e

   # Check staging deployment
   curl -f https://staging.gravitypm.com/health
   ```

2. **Deployment Execution**
   ```bash
   # Tag release
   git tag -a v1.2.3 -m "Release v1.2.3"

   # Push to trigger CI/CD
   git push origin main --tags
   ```

3. **Post-Deployment Validation**
   ```bash
   # Check production health
   curl -f https://api.gravitypm.com/health

   # Monitor for 30 minutes
   watch -n 60 'curl -s https://api.gravitypm.com/health'
   ```

### Rollback Procedure
1. **Identify Issue**
   - Check deployment logs
   - Review error metrics
   - Confirm user impact

2. **Execute Rollback**
   ```bash
   # Rollback to previous version
   git checkout v1.2.2
   git push origin main --force
   ```

3. **Validate Rollback**
   ```bash
   # Check system health
   curl -f https://api.gravitypm.com/health

   # Monitor metrics
   ```

### Blue-Green Deployment
1. **Prepare Green Environment**
   ```bash
   # Deploy to green environment
   docker-compose -f docker-compose.green.yml up -d
   ```

2. **Test Green Environment**
   ```bash
   # Run health checks
   curl -f http://green.gravitypm.com/health

   # Run smoke tests
   npm run smoke-test
   ```

3. **Switch Traffic**
   ```bash
   # Update load balancer
   aws elbv2 modify-listener \
     --listener-arn $LISTENER_ARN \
     --default-actions Type=forward,TargetGroupArn=$GREEN_TG_ARN
   ```

4. **Monitor and Cleanup**
   ```bash
   # Monitor for 30 minutes
   # If successful, decommission blue environment
   docker-compose -f docker-compose.blue.yml down
   ```

## Backup and Recovery

### Backup Schedule
- **Database**: Every 6 hours
- **File System**: Daily at 2 AM
- **Configuration**: Daily at 3 AM
- **Logs**: Continuous with rotation

### Recovery Procedures

#### Database Recovery
1. **Stop Application**
   ```bash
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml stop app
   ```

2. **Restore Database**
   ```bash
   # Restore from backup
   mongorestore --db gravitypm_production /opt/gravitypm/backups/db_backup.gz
   ```

3. **Start Application**
   ```bash
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml start app
   ```

4. **Validate Recovery**
   ```bash
   # Check data integrity
   curl -f https://api.gravitypm.com/health
   ```

#### File System Recovery
1. **Stop Services**
   ```bash
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml stop
   ```

2. **Restore Files**
   ```bash
   # Extract backup
   tar -xzf /opt/gravitypm/backups/fs_backup.tar.gz -C /opt/gravitypm/production/
   ```

3. **Start Services**
   ```bash
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml start
   ```

### Disaster Recovery
1. **Assess Situation**
   - Determine scope of disaster
   - Identify affected components
   - Estimate recovery time

2. **Execute DR Plan**
   - Activate backup site
   - Restore from off-site backups
   - Redirect traffic

3. **Communicate**
   - Update status page
   - Notify stakeholders
   - Provide regular updates

## Security Procedures

### Access Management
- **Principle of Least Privilege**: Grant minimum required access
- **Regular Audits**: Review access logs monthly
- **Multi-Factor Authentication**: Required for all admin access

### Security Monitoring
- **Log Analysis**: Monitor for suspicious activity
- **Intrusion Detection**: WAF and IDS alerts
- **Vulnerability Scanning**: Weekly automated scans

### Incident Response
1. **Detection**
   - Automated security alerts
   - Log analysis
   - User reports

2. **Assessment**
   - Determine scope and impact
   - Identify attack vector
   - Preserve evidence

3. **Containment**
   - Isolate affected systems
   - Block malicious traffic
   - Change compromised credentials

4. **Recovery**
   - Clean affected systems
   - Restore from backups
   - Monitor for recurrence

## Performance Management

### Performance Monitoring
- **Response Time**: Track 95th percentile
- **Throughput**: Monitor requests per second
- **Resource Usage**: CPU, memory, disk, network
- **Database Performance**: Query times, connection pools

### Optimization Procedures

#### Application Optimization
1. **Code Profiling**
   ```bash
   # Use performance monitoring tools
   npm run profile
   ```

2. **Database Optimization**
   ```bash
   # Analyze slow queries
   db.currentOp()
   ```

3. **Caching Strategy**
   ```bash
   # Implement Redis caching
   # Configure CDN
   ```

#### Infrastructure Scaling
1. **Horizontal Scaling**
   ```bash
   # Add more instances
   aws ecs update-service --cluster gravitypm --service app --desired-count 5
   ```

2. **Vertical Scaling**
   ```bash
   # Increase instance size
   aws ecs update-service --cluster gravitypm --task-definition larger-task
   ```

3. **Database Scaling**
   ```bash
   # Add read replicas
   aws rds create-db-instance-read-replica
   ```

## Maintenance Procedures

### Regular Maintenance Tasks

#### Weekly Tasks
- [ ] Review monitoring dashboards
- [ ] Check backup integrity
- [ ] Update security patches
- [ ] Review access logs
- [ ] Test failover procedures

#### Monthly Tasks
- [ ] Full backup verification
- [ ] Security assessment
- [ ] Performance review
- [ ] Capacity planning
- [ ] Compliance audit

#### Quarterly Tasks
- [ ] Disaster recovery test
- [ ] Load testing
- [ ] Architecture review
- [ ] Team training

### System Updates
1. **Plan Update**
   - Review release notes
   - Test in staging environment
   - Schedule maintenance window

2. **Execute Update**
   ```bash
   # Update system packages
   apt update && apt upgrade

   # Update application
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml pull
   docker-compose -f /opt/gravitypm/production/docker-compose.production.yml up -d
   ```

3. **Validate Update**
   ```bash
   # Run health checks
   curl -f https://api.gravitypm.com/health

   # Monitor for issues
   ```

### Log Rotation
```bash
# Configure logrotate
cat > /etc/logrotate.d/gravitypm << EOF
/opt/gravitypm/production/logs/*.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0644 www-data www-data
    postrotate
        docker-compose -f /opt/gravitypm/production/docker-compose.production.yml restart logging
    endscript
}
EOF
```

## Emergency Contacts

### On-Call Schedule
- **Primary**: John Doe (john.doe@gravitypm.com) - +1-555-0101
- **Secondary**: Jane Smith (jane.smith@gravitypm.com) - +1-555-0102
- **Management**: Bob Johnson (bob.johnson@gravitypm.com) - +1-555-0103

### External Contacts
- **AWS Support**: 1-888-280-4331
- **MongoDB Atlas**: support@mongodb.com
- **Domain Registrar**: support@namecheap.com
- **SSL Provider**: support@letsencrypt.org

### Escalation Matrix
- **Level 1**: On-call engineer
- **Level 2**: Engineering manager (after 30 minutes)
- **Level 3**: CTO (after 1 hour for Sev 1 incidents)
- **Level 4**: CEO (after 2 hours for Sev 1 incidents)

## Quick Reference

### Common Commands
```bash
# Check service status
docker-compose -f /opt/gravitypm/production/docker-compose.production.yml ps

# View logs
docker-compose -f /opt/gravitypm/production/docker-compose.production.yml logs -f

# Restart service
docker-compose -f /opt/gravitypm/production/docker-compose.production.yml restart <service>

# Check disk space
df -h

# Check memory
free -h

# Check processes
top

# Check network
netstat -tlnp
```

### Health Check Endpoints
- Application: https://api.gravitypm.com/health
- Database: https://api.gravitypm.com/health/db
- Cache: https://api.gravitypm.com/health/redis
- Load Balancer: https://gravitypm.com/health

### Log Locations
- Application: /opt/gravitypm/production/logs/app.log
- Nginx: /var/log/nginx/
- Database: /opt/gravitypm/production/logs/mongodb.log
- System: /var/log/syslog

---

**Last Updated**: $(date)
**Version**: 1.0
**Authors**: GravityPM Operations Team
