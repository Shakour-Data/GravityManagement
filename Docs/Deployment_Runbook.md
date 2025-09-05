# GravityPM Deployment Runbook

## Overview
This runbook provides step-by-step instructions for deploying GravityPM to staging and production environments.

## Prerequisites
- Docker and Docker Compose installed
- Access to staging and production servers
- Environment variables configured
- SSL certificates obtained

## Environments
- **Staging**: For testing and validation
- **Production**: Live environment

## Deployment Steps

### 1. Pre-Deployment Checklist
- [ ] Code reviewed and approved
- [ ] Tests passing
- [ ] Environment variables updated
- [ ] Database backups taken
- [ ] SSL certificates valid

### 2. Staging Deployment
```bash
# On staging server
git pull origin main
./scripts/deploy.sh staging
```

### 3. Staging Validation
- [ ] Frontend accessible at staging URL
- [ ] Backend API responding
- [ ] Database connections working
- [ ] Monitoring dashboards accessible
- [ ] Logs showing no errors

### 4. Production Deployment
```bash
# On production server
git pull origin main
./scripts/deploy.sh production
```

### 5. Post-Deployment Validation
- [ ] Frontend accessible
- [ ] API endpoints working
- [ ] User authentication working
- [ ] Data integrity verified
- [ ] Performance monitoring active

## Rollback Procedure
If issues arise after deployment:

1. Stop new containers: `docker-compose down`
2. Start previous version: `docker-compose up -d`
3. Investigate logs
4. Fix issues and redeploy

## Monitoring
- Check Grafana dashboards
- Monitor application logs
- Verify backup jobs
- Check SSL certificate expiry

## Emergency Contacts
- DevOps Team: devops@company.com
- Development Team: dev@company.com
- Infrastructure Support: infra@company.com

## Troubleshooting
- **Container fails to start**: Check logs with `docker-compose logs`
- **Database connection issues**: Verify environment variables
- **SSL errors**: Run `./scripts/ssl_renewal.sh`
- **Performance issues**: Check monitoring dashboards
