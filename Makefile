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
route53-list: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call route53-list,{profile})"

################################################################################
# LB region一覧
################################################################################
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
lb-list: profiles lb-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,lb) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call lb-list,{profile},{region})\""

################################################################################
# Lambda 一覧
################################################################################

################################################################################
# SQS 一覧
################################################################################

################################################################################
# SES 一覧
################################################################################

################################################################################
# Logs region一覧
################################################################################
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
log-groups: profiles log-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call service-regions,logs) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call log-groups,{profile},{region})\""

################################################################################
# KMS 一覧
################################################################################

################################################################################
# SSH key 一覧
################################################################################

################################################################################
# Cost Explorer 一覧
################################################################################


.PHONY: clean
clean:
	rm service-regions/*-regions
