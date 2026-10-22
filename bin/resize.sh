#!/bin/bash

#########################################################################
#                       FUNCTIONS :
#########################################################################

#this procedure return error message and number
usage () {
    echo "$0 -s [size] -d \"[device(s)]\" "
    echo "    size: number of gigabytes or MAX"
    echo "    device: block device name, for example /dev/sda"
    echo " "
    echo "Example: $0 -d \"/dev/sda /dev/sdb\" -s 10 "
    echo "Resize disk /dev/sda and /dev/sdb into size 10 GB"
    echo " "

    case $1 in
        1) echo "ERROR:   device isn't right defined"
            exit -$21;;
        2) echo "ERROR:   This device isn't right block device"
            exit -$22;;
        3) echo "ERROR:   Size isn't right defined"
            exit -3;;
        4) echo "ERROR:   Not allowed size"
            exit -$24;;
        5) echo "ERROR:   Any device isn't defined"
            exit -5;;
        *) echo "ERROR:   NOT implemented error"
            exit -$26;;
    esac
}
#this procedure resize one scsi disk
resize_one_disk(){

    if [ $2 = MAX ]
        then

        #getting max size in blocks
        size=`hdparm -N $1 | grep -oE "[[:digit:]]{1,}" | tail -n 1`
    else
        # get phisical sectors
        TMP=`hdparm -I $1 | grep "Phys" | grep -oE "[[:digit:]]{1,}" | sed -n '1p'`

        # calculate new size in sectors
        size=$(($2*1000000000/$TMP))
        
        #checking allowed max
        max=`hdparm -N $1 | grep -oE "[[:digit:]]{1,}" | tail -n 1`
        
        if [ $size -gt $max ]
            then
            usage 4 $3
        fi
    fi

    #real setting new size
    hdparm -N p$size --yes-i-know-what-i-am-doing $1

    sleep 2
}
# this procedure checks if disk transfer protocol is sas or scsi
check_disk_type(){
    local type_string=`smartctl -i $1 | grep "Transport protocol: SAS"`
    if [ "$type_string" = "Transport protocol: SAS" ]
    then
        DISK_TYPE="SAS"
    else
        DISK_TYPE="SCSI"
    fi
}

# this procedure calls resize_one_disk procedure
resize_scsi_disk(){
    STRING_MAX=`hdparm -I $1 | grep MAX`
    STRING_MAX=`expr "$STRING_MAX" : '[[:space:]]*\(.*\)[[:space:]]*$'`

    if [ "$STRING_MAX" == "SET_MAX security extension" ]
    then
        resize_one_disk $1 $2 $3
    else
        echo "!? Disk $1 not allow to set HPA"
    fi
}

# this procedure resizes sas disk
resize_sas_disk(){

    local SIZE=$2
    local blocks=0
    #checking the optarga s integer
    if [ $SIZE -eq $SIZE 2> /dev/null ]; then
        sector_size=`fdisk -l $1 2>/dev/null | grep "Sector size" | awk '{print $7}'`
        blocks=$(($2*1000000000/$sector_size))
    #otherwaise may by MAX
    elif [ "$SIZE" == "MAX" ]
    then
        blocks=-1
    else
        usage 3
    fi
    sg_format --resize --count=$blocks $1
}

#########################################################################
#                       MAIN PROGRAM :
#########################################################################

input=[]

while getopts  "s: d:" flag
do

  #checking flag d
  if [ $flag == "d" ]
  then
     input=($OPTARG)

  #checking flag s
  else
     #checking the optarga s integer
     if [ $OPTARG -eq $OPTARG 2> /dev/null ]; then
        SPACE=$OPTARG
     #otherwaise may by MAX
     elif [ "$OPTARG" == "MAX" ]
     then
        SPACE=$OPTARG
     else
        usage 3
     fi
  fi
done


if [ -z $SPACE ]
    then
    usage 3
fi


if [ ${#input[*]} -eq 0 ]
    then
    usage 5
fi


# MAIN LOOP:
i=0
for item in ${input[*]}
do
    if [ -z $item ]
    then
        usage 1 1
    elif [ ! -b $item ]
    then
        usage 2 1
    fi

    # is disk scsi or sas
    check_disk_type $item
    if [ "$DISK_TYPE" = "SAS" ]
    then
        resize_sas_disk $item $SPACE $i
    else
        resize_scsi_disk $item $SPACE $i
    fi
    echo ""
	echo "########################################################################"
	echo ""
    i=$(($i+1))
done

echo "Reboot your machine and enjoy your new sizes :)"
