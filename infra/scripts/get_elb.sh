#!/usr/bin/bash

if [ $# -lt 2 ]
then
        echo "Usage `basename $0` <Ingress Name> <namespace>"
        exit 1
fi

ING_NAME=$1
NAMESPACE=$2

sleep 20

ELB_NAME=`kubectl get ing -n ${NAMESPACE} | grep ${ING_NAME} | awk '{print $3}'`
ZONE_ID=`aws elbv2 describe-load-balancers | jq --arg DNSName $ELB_NAME -r '.LoadBalancers | .[] | select(.DNSName=="\($DNSName)") | .CanonicalHostedZoneId'`

echo "{"
echo '"elb_name": "'${ELB_NAME}'",'
echo '"zone_id": "'${ZONE_ID}'"'
echo "}"
