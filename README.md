## nixos2aws

### Getting started
- This repo relies on aws cli v2 and the boto3 python library
- You do not need to create an access token for this to work

#### The fast and direct way
```bash
# Log into your aws account
aws login --remote
# Create an ami from a .raw or .vhd image
python3 upload.py <path/to/image.raw> <region> <arch>
```

e.g.
```
aws login --remote
python3 upload.py osv.raw eu-north-1 x86_64
```

The script will print the name of the created AMI to stdout



### Going through S3 (this is very slow)

1. Log into the AWS console and create an EC2 bucket
    - General Purpose
    - Account Regional namespace (recommended)
    - Block Public Access
1. Run `just setup <BUCKET_NAME> <REGION>` (this will store your bucket name locally at `aws/.bucket`)
1. Run `just build aarch` to create a minimal vm image for arm. See `./flake.nix` for alternative images
1. Run `just upload` to upload the vm image into S3.
    - Note that this expects the `result` directory to contain a valid .vhd file
    - To upload from a custom path, run `just upload name path/to/file.format`
1. Run `just import-snapshot` to create a snapshot of the image.
    - For a custom image, run `just import-snapshot name format`
1. Wait until `just snapshot-status` shows that the snapshot is complete
1. Log into the EC2 console -> Elastic Block Stoage -> Snapshots
    1. Select newly imported snapshot
    1. Actions -> Create image from snapshot
    1. Create Image
1. Create a new EC2 instance and select the newly created AMI under 'My AMIs'

### Error handling
You may want to create snapshots in different regions. Doing so by just exchanging the bucket name will result in the following error:
```
[ERROR]: An error occurred (InvalidParameter) when calling the ImportSnapshot operation: The given S3 bucket (...) is not local to the region.
```
To fix, rerun the `setup` target with the correct region and bucket
