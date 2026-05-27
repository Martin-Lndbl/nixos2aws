## nixos2aws

### Getting started
- This repo relies on aws cli v2
- You do not need to create an access token for this to work


1. Log into the AWS console and create an EC2 bucket
    - General Purpose
    - Account Regional namespace (recommended)
    - Block Public Access
1. Run `just setup <BUCKET_NAME>` (this will store your bucket name locally at `aws/.bucket`)
1. Run `just build image=minimal` to create a minimal vm image. See `./configurations` for alternative images
1. Run `just upload` to upload the vm image into S3. Note that this expects the `result` directory to contain a valid .vhd file
1. Run `just import-snapshot` to create a snapshot of the image. Note the <ImportTaskId> for the next step
1. Wait until `just snapshot-status <ImportTaskId>` shows that the snapshot is complete
1. Log into the EC2 console -> Elastic Block Stoage -> Snapshots
    1. Select newly imported snapshot
    1. Actions -> Create image from snapshot
    1. Create Image
1. Create a new EC2 instance and select the newly created AMI under 'My AMIs'
