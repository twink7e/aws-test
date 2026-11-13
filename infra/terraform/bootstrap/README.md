# Bootstrap: Terraform state storage

This directory creates the S3 bucket used by the other Terraform layers. It deliberately keeps **local state** so that it can run before the remote backend exists. Run it once with an AWS identity that can administer S3, then protect its local `terraform.tfstate` file. The bucket has versioning, encryption, public access blocking, TLS enforcement, and Terraform's `prevent_destroy` guard. Terraform S3 `use_lockfile = true` is used in the other layers; DynamoDB is unnecessary.

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform and AWS provider versions, default tags. |
| `variables.tf` | Tokyo Region and project naming inputs. |
| `main.tf` | Versioned, encrypted S3 state bucket and access controls. |
| `outputs.tf` | Bucket name for the next two layers. |
| `terraform.tfvars.example` | Safe example inputs. |

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
terraform output -raw state_bucket_name
```

The bucket name includes the AWS account ID and Region. Copy the output into `../foundation/backend.hcl` and `../workload/backend.hcl`. Keep this state bucket until after both other layers are destroyed and their state is archived or no longer needed.
