iac-tke
====

使用 Terraform 创建一个测试用途的腾讯云 TKE 集群。

- 配置并提供以下用于调用腾讯云API的环境变量：
    - `export TENCENTCLOUD_SECRET_ID="<my-secret-id>"`
    - `export TENCENTCLOUD_SECRET_KEY="<my-secret-key>"`
    - `export TENCENTCLOUD_REGION="ap-guangzhou"`

- `terraform init`

- `terraform apply`
