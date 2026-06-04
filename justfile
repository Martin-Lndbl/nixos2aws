default_bucket := `cat aws/.bucket 2>/dev/null || echo ""`

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

setup bucket: login (roles bucket)
  echo "{{bucket}}" > aws/.bucket

build image="x86":
  #!/usr/bin/env bash
  nix build .#{{image}}

upload image="nixos-base-image.vhd":
  #!/usr/bin/env bash
  aws s3 cp result/*.vhd s3://{{default_bucket}}/{{image}}


import-snapshot bucket=default_bucket image="nixos-base-image.vhd": create-aws
  #!/usr/bin/env bash
  cat <<EOF > aws/containers.json
  {
    "Description": "NixOS Base VHD Image",
    "Format": "VHD",
    "UserBucket": {
        "S3Bucket": "{{bucket}}",
        "S3Key": "{{image}}"
    }
  }
  EOF
  aws ec2 import-snapshot --description "NixOS Disk Snapshot" --disk-container file://aws/containers.json

snapshot-status task-id:
  aws ec2 describe-import-snapshot-tasks --import-task-ids {{task-id}}

clean:
  rm -dr aws
  aws iam delete-role-policy --role-name vmimport --policy-name vmimport
  aws iam delete-role --role-name vmimport
  aws logout

