/*the format of config json,*/
{
		"ControlSet":{
				"MacWhiteListSetName":,
				"IpWhiteListSetName":,
				"MacBlackListSetName":,
				"IpBlackListSetName":,
		}
		"ControlRule": [
				{		
					"Id":,
					"SrcZoneIds":[],
					"SrcIpgrpIds":[],
					"DstZoneIds":[],
					"DstIpgrpIds":[],
					"ProtoIds":[],
					"Action":["AC_ACCEPT", "AC_AUDIT"] //组合
				},
		],
		"AuditSet": {
				"MacWhiteListSetName":,
				"IPWhiteListSetName":,
		},
		"AuditRule":[
					{		
							"Id":,
							"SrcZoneIds":[],
							"SrcIpgrpIds":[],
							"DstZoneIds":[],
							"DstIpgrpIds":[],
							"ProtoIds":[],
							"Action":["AC_ACCEPT", "AC_AUDIT"] //组合
					},
				{}
		]
	}