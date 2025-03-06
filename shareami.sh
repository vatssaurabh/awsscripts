#!/bin/bash

AWS_PROFILE=""
DEST_REGION="us-west-2"
SOURCE_REGION="us-east-1"
SOURCE_AMI_ID=""
TARGET_USER_ID=""
AMI_NAME="PMv5 SL AMI Promoted from stg"
AMI_DESCRIPTION="Shared AMI from $SOURCE_REGION"
MAX_TRIES=5
COUNTER=1
SNAPSHOT_IDS=""

TAGS_JSON=$(aws ec2 describe-images \
            --region $SOURCE_REGION \
			--image-ids $SOURCE_AMI_ID \
			--profile $AWS_PROFILE \
			--query 'Images[*].Tags' \
			--output json)
			

#!/bin/bash



# Extract Key-Value pairs and format them into a compact JSON array
TAGS=$(echo "$TAGS_JSON" | grep -oP '"Key": "\K[^"]+|"Value": "\K[^"]+' | sed 'N;s/\n/ /' | awk '
BEGIN { printf "[" }
{
    if (NR > 1) printf ","
    printf "{\Key\=\%s\,\Value\=\%s\}", $1, $2
}
END { printf "]" }
')


 #Output the result
echo "$TAGS"

echo "Copying AMI to $DEST_REGION..."
 NEW_AMI_ID=$(aws ec2 copy-image \
        --region $DEST_REGION \
        --source-region $SOURCE_REGION \
        --source-image-id $SOURCE_AMI_ID \
        --name "$AMI_NAME" \
        --description "$AMI_DESCRIPTION" \
        --query "ImageId" \
		--tag-specifications "ResourceType=image,Tags=$TAGS" \
		--profile $AWS_PROFILE \
        --output text)
		
 
	
# Wait for the AMI to become available
while [ $COUNTER -le $MAX_TRIES ]
do
    state=$(aws ec2 describe-images --image-ids $NEW_AMI_ID --region $DEST_REGION --query "Images[0].State" --profile $AWS_PROFILE --output text)
    if [ "$state" == "available" ]; then
        echo "AMI is now available."
		aws ec2 modify-image-attribute \
			  --image-id $NEW_AMI_ID \
			  --launch-permission "Add=[{UserId=$TARGET_USER_ID}]" \
			  --region $DEST_REGION \
			  --profile $AWS_PROFILE
			  
		SNAPSHOT_ID=$(aws ec2 describe-images \
					--region $DEST_REGION \
					--image-ids $NEW_AMI_ID \
					--query "Images[0].BlockDeviceMappings[*].Ebs.SnapshotId" \
					--profile $AWS_PROFILE \
					--output text)
		echo "SNAPSHOT_IDS $SNAPSHOT_ID"
	    aws ec2 modify-snapshot-attribute \
			  --snapshot-id $SNAPSHOT_ID \
			  --attribute createVolumePermission \
			  --operation-type add --user-ids $TARGET_USER_ID \
			  --region $DEST_REGION \
			  --profile $AWS_PROFILE				
 
        echo "AMI $NEW_AMI_ID shared in $DEST_REGION."
        break
    else
        echo "AMI is still in state: $state. Waiting..."
		sleep 300
    fi
	COUNTER=$((COUNTER + 1))
done

 	


		
 	
	
