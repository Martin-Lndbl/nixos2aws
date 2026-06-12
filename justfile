default_bucket := `cat aws/.bucket 2>/dev/null || echo ""`
default_region := `cat aws/.region 2>/dev/null || echo ""`
default_import-task-id := `cat aws/.import-task-id 2>/dev/null || echo ""`
default_snapshot-id := `cat aws/.snapshot-id 2>/dev/null || echo ""`

test:
  echo {{default_bucket}}

login:
  #!/usr/bin/env bash
  AWS_USER=$(aws sts get-caller-identity --query "Arn" --output text 2>/dev/null)

  if [ $? -eq 0 ]; then
      echo "⚠️  Already logged in as: $AWS_USER. Skipping login..."
      exit 0
  else 
    aws login --remote
  fi


create-aws:
  #!/usr/bin/env bash
  mkdir -p aws 2>/dev/null

roles bucket=default_bucket: create-aws
  #!/usr/bin/env bash
  cat <<EOF > aws/trust-policy.json
  {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Service": "vmie.amazonaws.com"
        },
        "Action": "sts:AssumeRole",
        "Condition": {
            "StringEquals": {
                "sts:Externalid": "vmimport"
            }
        }
    }]
  }
  EOF
  cat <<EOF > aws/role-policy.json
  {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"],
        "Resource": ["arn:aws:s3:::{{bucket}}", "arn:aws:s3:::{{bucket}}/*"]
    }, {
        "Effect": "Allow",
        "Action": ["ec2:ModifySnapshotAttribute", "ec2:CopySnapshot", "ec2:RegisterImage", "ec2:Describe*"],
        "Resource": "*"
    }]
  }
  EOF
  if aws iam get-role --role-name vmimport >/dev/null 2>&1; then
    echo "⚠️  Role vmimport already exists. Skipping creation."
  else
    aws iam create-role --role-name vmimport --assume-role-policy-document file://aws/trust-policy.json
  fi
  aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file://aws/role-policy.json

setup bucket region: login (roles bucket)
  echo "{{bucket}}" > aws/.bucket
  echo "{{region}}" > aws/.region

build image="x86":
  #!/usr/bin/env bash
  nix build .#{{image}}

upload image="nixos-base-image.vhd" src="result/*.vhd":
  #!/usr/bin/env bash
  aws s3 cp {{src}} s3://{{default_bucket}}/{{image}}


import-snapshot image="nixos-base-image.vhd" format="VHD" bucket=default_bucket region=default_region : create-aws
  #!/usr/bin/env bash
  cat <<EOF > aws/container.json
  {
    "Description": "Custom {{format}} Image",
    "Format": "{{format}}",
    "UserBucket": {
        "S3Bucket": "{{bucket}}",
        "S3Key": "{{image}}"
    }
  }
  EOF
  IMPORT_TASK_ID=$(aws ec2 import-snapshot \
    --description "Disk Snapshot" \
    --region {{region}} \
    --disk-container file://aws/container.json \
    | jq -r '.ImportTaskId')
  echo "$IMPORT_TASK_ID" > aws/.import-task-id

  echo "Waiting for snapshot import to complete (task: $IMPORT_TASK_ID)..."
  while true; do
    RESULT=$(aws ec2 describe-import-snapshot-tasks \
      --region {{region}} \
      --import-task-ids "$IMPORT_TASK_ID")
    STATUS=$(echo "$RESULT" | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.Status')
    echo "  Status: $STATUS"
    if [[ "$STATUS" == "completed" ]]; then
      SNAPSHOT_ID=$(echo "$RESULT" | jq -r '.ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId')
      echo "$SNAPSHOT_ID" > aws/.snapshot-id
      echo "Snapshot complete: $SNAPSHOT_ID"
      break
    elif [[ "$STATUS" == "deleted" || "$STATUS" == "deleting" ]]; then
      echo "Snapshot import failed with status: $STATUS" >&2
      exit 1
    fi
    sleep 15
  done

snapshot-status task-id=default_import-task-id region=default_region:
  #!/usr/bin/env bash
  aws ec2 describe-import-snapshot-tasks --region {{region}} --import-task-ids {{task-id}}

create-ami name arch snapshot-id=default_snapshot-id region=default_region:
  #!/usr/bin/env bash
  aws ec2 register-image \
  --name "{{name}}" \
  --description "{{name}} image" \
  --region {{region}} \
  --architecture {{arch}} \
  --virtualization-type hvm \
  --boot-mode legacy-bios \
  --root-device-name "/dev/sda1" \
  --block-device-mappings '[{
    "DeviceName": "/dev/sda1",
    "Ebs": {
      "SnapshotId": "{{snapshot-id}}",
      "VolumeSize": 5,
      "DeleteOnTermination": true,
      "VolumeType": "gp3"
    }
  }]'


upload-direct src region arch:
  python3 upload.py {{src}} {{region}}

clean:
  rm -dr aws
  aws iam delete-role-policy --role-name vmimport --policy-name vmimport
  aws iam delete-role --role-name vmimport
  aws logout

