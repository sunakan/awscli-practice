SERVICE_REGIONS_PATH := ${PWD}/service-regions

################################################################################
# aws コマンドで --profile PROFILE で利用する一覧表示（ないならdefaultが入る）
################################################################################
define profiles
	cat profiles | grep --invert-match '#'
endef
.PHONY: profiles
profiles:
	$(call profiles) || echo default > profiles

################################################################################
# profileの疎通確認
################################################################################
# $(1)：profile名
define sts-check
	aws sts get-caller-identity --profile $(1)
endef
.PHONY: check
check: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call sts-check,{profile})"

################################################################################
# IAM User一覧
################################################################################
# $(1)：profile名
define iam-users
	export AWS_PAGER='' \
		&& aws iam list-users --query 'Users[].UserName' --profile $(1) \
			| jq --raw-output '.[]'
endef
.PHONY: iam-users
iam-users: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call iam-users,{profile})"

################################################################################
# IAM Role一覧
################################################################################
# $(1)：profile名
define iam-roles
	export AWS_PAGER='' \
		&& aws iam list-roles --query 'Roles[].RoleName' --profile $(1) \
			| jq --raw-output '.[]'
endef
.PHONY: iam-roles
iam-roles: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call iam-roles,{profile})"

################################################################################
# AWSサービス region一覧
################################################################################
# $(1)：サービス名
define service-regions
	cat ${SERVICE_REGIONS_PATH}/$(1)-regions | grep --invert-match '#'
endef

################################################################################
# EC2 region一覧（テキストに吐き出す（もし不要な部分があれば、自分で削っていく））
################################################################################
.PHONY: ec2-regions
ec2-regions: profiles
	$(call service-regions,ec2) \
		|| ( \
			aws ec2 describe-regions --query 'Regions[*].RegionName[]' \
				| jq --raw-output '.[]' > ${SERVICE_REGIONS_PATH}/ec2-regions.all \
				&& cp ${SERVICE_REGIONS_PATH}/ec2-regions.all ${SERVICE_REGIONS_PATH}/ec2-regions \
		)

################################################################################
# VPC一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define vpc-list
	export AWS_PAGER='' \
		&& aws ec2 describe-vpcs --query 'Vpcs[].{CidrBlock: CidrBlock, Tags: Tags[0]}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: vpc-list
vpc-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,ec2) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call vpc-list,{profile},{region})\""

################################################################################
# VPC Subnet一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define vpc-subnet-list
	export AWS_PAGER='' \
		&& aws ec2 describe-subnets --query 'Subnets[].{VpcId: VpcId, CidrBlock: CidrBlock}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: vpc-subnet-list
vpc-subnet-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,ec2) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call vpc-subnet-list,{profile},{region})\""

################################################################################
# EC2 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define ec2-list
	export AWS_PAGER='' \
		&& aws ec2 describe-instances --query 'Reservations[].Instances[].{InstanceType: InstanceType, PublicIp: PublicIpAddress, IamInstanceProfile: IamInstanceProfile.Arn, Tags: Tags}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: ec2-list
ec2-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,ec2) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call ec2-list,{profile},{region})\""

################################################################################
# S3 一覧
################################################################################
# $(1)：profile名
define s3-list
	export AWS_PAGER='' \
		&& aws s3 ls --profile $(1)
endef
.PHONY: s3-list
s3-list: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call s3-list,{profile})"

################################################################################
# RDS region一覧
################################################################################
.PHONY: rds-regions
rds-regions:
	$(call service-regions,rds) || cp ${SERVICE_REGIONS_PATH}/rds-regions.all ${SERVICE_REGIONS_PATH}/rds-regions

################################################################################
# RDS 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define rds-list
	export AWS_PAGER='' \
		&& aws rds describe-db-instances --query 'DBInstances[].{DBInstanceIdentifier: DBInstanceIdentifier, Engine: Engine, EngineVersion: EngineVersion, MultiAZ: MultiAZ}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: rds-list
rds-list: profiles rds-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,rds) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call rds-list,{profile},{region})\""

################################################################################
# Route53 一覧
################################################################################
# $(1)：profile名
define route53-list
	export AWS_PAGER='' \
		&& aws route53 list-hosted-zones --query 'HostedZones[].Name' --profile $(1) \
			| jq --raw-output --compact-output '.'
endef
.PHONY: route53-list
route53-list: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call route53-list,{profile})"

################################################################################
# LB region一覧
################################################################################
.PHONY: lb-regions
lb-regions:
	$(call service-regions,lb) || cp ${SERVICE_REGIONS_PATH}/lb-regions.all ${SERVICE_REGIONS_PATH}/lb-regions

################################################################################
# LB 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define lb-list
	export AWS_PAGER='' \
		&& aws elbv2 describe-load-balancers --query 'LoadBalancers[].{Name: LoadBalancerName, Type: Type, Scheme: Scheme, SubnetIds: [AvailabilityZones[].SubnetId]}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: lb-list
lb-list: profiles lb-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,lb) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call lb-list,{profile},{region})\""

################################################################################
# Lambda region一覧
################################################################################
.PHONY: lambda-regions
lambda-regions:
	$(call service-regions,lambda) || cp ${SERVICE_REGIONS_PATH}/lambda-regions.all ${SERVICE_REGIONS_PATH}/lambda-regions

################################################################################
# Lambda 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define lambda-list
	export AWS_PAGER='' \
		&& aws lambda list-functions --query 'Functions[].[FunctionName,Handler,Runtime,MemorySize]' --output table --profile $(1) --region $(2)
endef
.PHONY: lambda-list
lambda-list: profiles lambda-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,lambda) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call lambda-list,{profile},{region})\""

################################################################################
# SQS region一覧
################################################################################
.PHONY: sqs-regions
sqs-regions:
	$(call service-regions,sqs) || cp ${SERVICE_REGIONS_PATH}/sqs-regions.all ${SERVICE_REGIONS_PATH}/sqs-regions

################################################################################
# SQS 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define sqs-list
	export AWS_PAGER='' \
		&& aws sqs list-queues --query 'QueueUrls' --profile $(1) --region $(2)
endef
.PHONY: sqs-list
sqs-list: profiles sqs-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,sqs) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call sqs-list,{profile},{region})\""

################################################################################
# SES region一覧
################################################################################
.PHONY: ses-regions
ses-regions:
	$(call service-regions,ses) || cp ${SERVICE_REGIONS_PATH}/ses-regions.all ${SERVICE_REGIONS_PATH}/ses-regions

################################################################################
# SES 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define ses-list
	export AWS_PAGER='' \
		&& aws ses list-identities --query 'Identities' --profile $(1) --region $(2)
endef
.PHONY: ses-list
ses-list: profiles ses-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,ses) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call ses-list,{profile},{region})\""

################################################################################
# Logs region一覧
################################################################################
.PHONY: log-regions
log-regions:
	$(call service-regions,logs) || cp ${SERVICE_REGIONS_PATH}/logs-regions.all ${SERVICE_REGIONS_PATH}/logs-regions

################################################################################
# Logs group一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define log-groups
	export AWS_PAGER='' \
		&& aws logs describe-log-groups --query 'logGroups[].{Name: logGroupName, metricFilterCount: metricFilterCount, storedBytes: storedBytes}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: log-groups
log-groups: profiles log-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,logs) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call log-groups,{profile},{region})\""

################################################################################
# 各Log groupの最新のログストリーム一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define log-latest-streams
	$(call log-groups,$(1),$(2)) \
		| jq --raw-output '.Name' \
		| xargs -I {log-group} aws logs describe-log-streams --log-group-name '{log-group}' --query 'logStreams' --order-by LastEventTime --profile $(1) --region $(2) \
		| jq --raw-output --compact-output 'sort_by(.latestEventTimestamp) | reverse | .[0] | {arn: .arn, logStreamName: .logStreamName, storedBytes: .storedBytes}'
endef
.PHONY: log-latest-streams
log-latest-streams:
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,logs) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call log-latest-streams,{profile},{region})\""

################################################################################
# KMS region一覧
################################################################################
.PHONY: kms-regions
kms-regions:
	$(call service-regions,kms) || cp ${SERVICE_REGIONS_PATH}/kms-regions.all ${SERVICE_REGIONS_PATH}/kms-regions

################################################################################
# KMS 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define kms-list
	export AWS_PAGER='' \
		&& aws kms list-keys --query 'Keys[].KeyId' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]' \
			| xargs -I {key-id} bash -c 'aws kms list-grants --query 'Grants[].Name' --key-id {key-id} --profile $(1) --region $(2) | jq --raw-output --compact-output '.[]''
endef
.PHONY: kms-list
kms-list: profiles kms-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,kms) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call kms-list,{profile},{region})\""

################################################################################
# SSH keypair 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define key-pairs
	export AWS_PAGER='' \
		&& aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: key-pairs
key-pairs: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,ec2) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call key-pairs,{profile},{region})\""

################################################################################
# Cost Explorer 一覧
################################################################################


################################################################################
# 上記全て
################################################################################
.PHONY: lists
lists:
	make check
	make iam-users
	make iam-roles
	make vpc-list
	make vpc-subnet-list
	make ec2-list
	make s3-list
	make rds-regions
	make rds-list
	make route53-list
	make lb-list
	make lambda-list
	make sqs-list
	make ses-list
	make log-groups
	make kms-list
	make key-pairs

.PHONY: clean
clean:
	rm service-regions/*-regions
