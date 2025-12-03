import boto3
import datetime
import json
import os
from dateutil.parser import parse

# Initialize the clients
ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
redshift_client = boto3.client('redshift')
savings_plan_client = boto3.client('savingsplans')
sns_client = boto3.client('sns')

def lambda_handler(event, context):
    warning_threshold_days = int(event.get('warning_exp', 30))
    alert_threshold_days = int(event.get('alert_exp', 7))
    now = datetime.datetime.now(datetime.timezone.utc)
    last_24_hours = now - datetime.timedelta(days=1)

    expiring_savings_plans = []
    expiring_ris = {
        'EC2': [],
        'RDS': [],
        'Redshift': []
    }

    notifications = {
        'Warning': [],
        'Alert': []
    }

    # Iterate over Savings Plans
    savings_plans_response = savings_plan_client.describe_savings_plans()
    for plan in savings_plans_response['savingsPlans']:
        expiration_date = parse(plan['end'])
        days_until_expiration = (expiration_date - now).days

        if 0 <= days_until_expiration <= warning_threshold_days:
            category = 'Alert' if days_until_expiration <= alert_threshold_days else 'Warning'
            notifications[category].append({
                'Type': 'SavingsPlan - {}'.format(plan['savingsPlanType']),
                'Description': plan['description'],
                'PaymentOption': plan['paymentOption'],
                'Commitment': plan['commitment'],
                'Id': plan['savingsPlanId'],
                'ExpiryDate': plan['end']
            })

    # Iterate over EC2 Reserved Instances
    ec2_ris = ec2_client.describe_reserved_instances(Filters=[{'Name': 'state', 'Values': ['active']}])
    for ri in ec2_ris['ReservedInstances']:
        expiration_date = ri['End']
        days_until_expiration = (expiration_date - now).days

        if 0 <= days_until_expiration <= warning_threshold_days:
            category = 'Alert' if days_until_expiration <= alert_threshold_days else 'Warning'
            notifications[category].append({
                'Type': 'EC2 RI',
                'Id': ri['ReservedInstancesId'],
                'ExpiryDate': ri['End'].strftime('%Y-%m-%dT%H:%M:%SZ')
            })

    # Iterate over RDS Reserved Instances
    rds_ris = rds_client.describe_reserved_db_instances()
    for ri in rds_ris['ReservedDBInstances']:
        if 'EndTime' not in ri:
            continue

        expiration_date = ri['EndTime']
        days_until_expiration = (expiration_date - now).days

        if 0 <= days_until_expiration <= warning_threshold_days:
            category = 'Alert' if days_until_expiration <= alert_threshold_days else 'Warning'
            notifications[category].append({
                'Type': 'RDS RI',
                'Id': ri['ReservedDBInstanceId'],
                'ExpiryDate': ri['EndTime'].strftime('%Y-%m-%dT%H:%M:%SZ')
            })

    # Iterate over Redshift Reserved Nodes
    redshift_nodes = redshift_client.describe_reserved_nodes()
    for node in redshift_nodes['ReservedNodes']:
        expiration_date = node['EndTime']
        days_until_expiration = (expiration_date - now).days

        if 0 <= days_until_expiration <= warning_threshold_days:
            category = 'Alert' if days_until_expiration <= alert_threshold_days else 'Warning'
            notifications[category].append({
                'Type': 'Redshift Node',
                'Id': node['ReservedNodeId'],
                'ExpiryDate': node['EndTime'].strftime('%Y-%m-%dT%H:%M:%SZ')
            })

    if notifications['Warning'] or notifications['Alert']:
        sns_topic_arn = os.environ['SNS_TOPIC_ARN']  # SNS Topic ARN from environment variable
        message = {
            "Warning": notifications['Warning'],
            "Alert": notifications['Alert']
        }
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=json.dumps(message),
            Subject="Expiring SPs and RIs Notification"
        )
