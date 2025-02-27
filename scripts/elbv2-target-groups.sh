#!/bin/bash
if [ "$1" != "" ]; then
    if [[ "$1" == *":targetgroup"* ]];then
        cmd[0]="$AWS elbv2 describe-target-groups --target-group-arn \"$1\""
    else
        cmd[0]="$AWS elbv2 describe-target-groups --load-balancer-arn \"$1\""
    fi 

else
    echo "must pass tgt group or lb arn"
    exit
fi

c=0
cm=${cmd[$c]}

pref[0]="TargetGroups"
tft[0]="aws_lb_target_group"
idfilt[0]="TargetGroupArn"

for c in `seq 0 0`; do
 
    cm=${cmd[$c]}
	ttft=${tft[(${c})]}
	#echo $cm
    awsout=`eval $cm 2> /dev/null`
    if [ "$awsout" == "" ];then
        echo "$cm : You don't have access for this resource"
        exit
    fi
    count=`echo $awsout | jq ".${pref[(${c})]} | length"`
    if [ "$count" -gt "0" ]; then
        count=`expr $count - 1`
        for i in `seq 0 $count`; do
            #echo $i
            cname=`echo $awsout | jq ".${pref[(${c})]}[(${i})].${idfilt[(${c})]}" | tr -d '"'`
            echo "$ttft $cname"
            rname=${cname//:/_} && rname=${rname//./_} && rname=${rname//\//_}
            #
            # should get them all really 
            #
            lbarn=$(echo $awsout | jq ".${pref[(${c})]}[(${i})].LoadBalancerArns[0]" | tr -d '"')
            fn=`printf "%s__%s.tf" $ttft $rname`
            #echo $fn
            if [ -f "$fn" ] ; then echo "$fn exists already skipping" && continue; fi

            fn=`printf "%s__%s.tf" $ttft $rname`
            
            printf "resource \"%s\" \"%s\" {\n" $ttft $rname > $fn
            printf "}"  >> $fn
            
            terraform import $ttft.$rname "$cname" | grep Importing
            terraform state show -no-color $ttft.$rname > t1.txt
            
            rm -f $fn

            file="t1.txt"
            
         
            #echo "#" > $fn
            echo $aws2tfmess > $fn
            while IFS= read line
            do
				skip=0
                # display $line or do something with $line
                t1=`echo "$line"` 
                if [[ ${t1} == *"="* ]];then
                    tt1=`echo "$line" | cut -f1 -d'=' | tr -d ' '` 
                    tt2=`echo "$line" | cut -f2- -d'='`
                    if [[ ${tt1} == "arn" ]];then
                        if [[ ${tt2} == *"targetgroup"* ]];then
                            skip=1
                        else
                            skip=0; 
                        fi
                    fi                
                    if [[ ${tt1} == "id" ]];then skip=1; fi          
                    if [[ ${tt1} == "role_arn" ]];then skip=1;fi
                    if [[ ${tt1} == "owner_id" ]];then skip=1;fi
                    if [[ ${tt1} == "association_id" ]];then skip=1;fi

                    if [[ ${tt1} == "dns_name" ]];then skip=1;fi
                    #if [[ ${tt1} == "vpc_id" ]];then skip=1;fi
                    if [[ ${tt1} == "default_version" ]];then skip=1;fi
                    if [[ ${tt1} == "latest_version" ]];then skip=1;fi
                    if [[ ${tt1} == "security_group_names" ]];then skip=1;fi
                    if [[ ${tt1} == "zone_id" ]];then skip=1;fi
                    if [[ ${tt1} == "arn_suffix" ]];then skip=1;fi
                    #if [[ ${tt1} == "ipv6_cidr_block" ]];then skip=1;fi
                    if [[ ${tt1} == "subnet_id" ]]; then
                        tt2=`echo $tt2 | tr -d '"'`
                        t1=`printf "%s = aws_subnet.%s.id" $tt1 $tt2`
                    fi
                    if [[ ${tt1} == "vpc_id" ]]; then
                        vpcid=`echo $tt2 | tr -d '"'`
                        t1=`printf "%s = aws_vpc.%s.id" $tt1 $vpcid`
                    fi
                
                else
                    if [[ ${t1} == *"target_failover {}"* ]]; then
                        skip=1
                    fi
                fi
                
                if [ "$skip" == "0" ]; then
                    #echo $skip $t1
                    echo "$t1" >> $fn
                fi
                
            done <"$file"

            if [[ "${vpcid}" != "" ]]; then
                ../../scripts/100-get-vpc.sh $vpcid
            fi
            if [[ "${lbarn}" != "" ]]; then
                ../../scripts/elbv2.sh $lbarn
            fi
        done
    fi
done

#rm -f t*.txt

