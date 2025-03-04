#!/bin/bash

AWS_PROFILE=""
DEST_REGION="us-west-2"
AWS_ACCOUNT=""
SOURCE_REGION="us-east-1"
SOURCE_AMI_ID=""
TARGET_USER_ID="171037455572"
AMI_NAME="PMv5 SL AMI Promoted from stg"
AMI_DESCRIPTION="Shared AMI from $SOURCE_REGION"
MAX_TRIES=5
COUNTER=1

 echo "Copying AMI to $DEST_REGION..."
 NEW_AMI_ID=$(aws ec2 copy-image \
        --region $DEST_REGION \
        --source-region $SOURCE_REGION \
        --source-image-id $SOURCE_AMI_ID \
        --name "$AMI_NAME" \
        --description "$AMI_DESCRIPTION" \
        --query "ImageId" \
		--tag-specifications 'ResourceType=image,Tags=[{Key=Environment,Value=PROMOTED-FROM-STG-TO-PRD},{Key=Project,Value=PMV5SL}]' \
		--profile $AWS_PROFILE \
        --output text)
		
 SNAPSHOT_IDS=$(aws ec2 describe-images \
    --region $DEST_REGION \
    --image-ids $NEW_AMI_ID \
    --query "Images[0].BlockDeviceMappings[*].Ebs.SnapshotId" \
	--profile $AWS_PROFILE \
    --output text)	
	
# Wait for the AMI to become available
while [ $COUNTER -le $MAX_TRIES ]
do
    state=$(aws ec2 describe-images --image-ids $NEW_AMI_ID --region $DEST_REGION --query "Images[0].State" --profile $AWS_PROFILE --output text)
    if [ "$state" == "available" ]; then
        echo "AMI is now available."
		echo "Sharing AMI $NEW_AMI_ID in $DEST_REGION with $TARGET_USER_ID..."
		  aws ec2 modify-image-attribute \
			  --image-id $NEW_AMI_ID \
			  --launch-permission "Add=[{UserId=$TARGET_USER_ID}]" \
			  --region $DEST_REGION \
			  --profile $AWS_PROFILE
 
        echo "Done"
		for SNAPSHOT_ID in $SNAPSHOT_IDS; do
		echo "Snapshot ID: $SNAPSHOT_ID"
		  aws ec2 modify-snapshot-attribute \
			  --snapshot-id $SNAPSHOT_ID \
			  --attribute createVolumePermission \
			  --operation-type add --user-ids $TARGET_USER_ID \
			  --region $DEST_REGION \
			  --profile $AWS_PROFILE

		done
 
        echo "AMI $NEW_AMI_ID shared in $DEST_REGION."
        break
    else
        echo "AMI is still in state: $state. Waiting..."
		sleep 300
    fi
	COUNTER=$((COUNTER + 1))
done

