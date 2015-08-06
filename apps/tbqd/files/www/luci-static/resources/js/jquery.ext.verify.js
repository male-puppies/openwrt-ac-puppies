/*
*	一个数据验证的demo
* 	有两种使用方法: 
*	1. 在数据提交时显示调用 verification(); 返回true则验证成功, 否则提示错误信息(需要完善).
*	2. 在documents.ready回调里面 verifyEventsInit(); 将input控件的blur事件绑定到验证函数, 自动触发.
*/
!function(root){
	var VerifyImplication = {
		"string": {
			method: function(val, regexp){
				//alert(val);
				return true;
			},
			message: ""
		},
		"ip": {
			method: function(ip){
				var regExp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				if(regExp.test(ip)){
					var results = ip.match(regExp);
					if(+results[1] == 127 || +results[1]>=224){
						return false;
					}
					return true;
				}
				return false;
			},
			message: "请正确输入IP地址."
		},
		"achost": {
			method: function(ip){
				var regExp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				if(regExp.test(ip)){
					var results = ip.match(regExp);
					if(+results[1] == 127 || +results[1]>=224){
						return false;
					}
					return true;
				}
				return false;
			},
			message: "请正确输入控制器地址."
		},
		"gateway": {
			method: function(ip){
				var regExp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				if(regExp.test(ip)){
					var results = ip.match(regExp);
					if(+results[1] == 127 || +results[1]>=224){
						return false;
					}
					return true;
				}
				return false;
			},
			message: "请正确输入网关."
		},
		"iprange":{
			method:function(val){
				var ip_regExp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				var ipRg_regExp = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
				var reg_s = /\S/;
				val = val.trim();
				var arr = val.split('\n');
				for(var k = 0; k< arr.length; k++){
					if(ip_regExp.test(arr[k]) || ipRg_regExp.test(arr[k])){
						
					}else{
						return false;	
					}
				}
				return true;
			},
			message:"非法ip格式范围"	
		},
		"mask": {
			method: function(val){
				var m=new Array(),
					mn = val.split(".");
				
				if(val == "0.0.0.0" || val == "255.255.255.255"){
					return false;
				}
				if (mn.length==4) {
					for (i=0;i<4;i++) {
						m[i]=mn[i];
					}
				} else {
					return false;
				}
			
				var v=(m[0]<<24)|(m[1]<<16)|(m[2]<<8)|(m[3]);
			
				var f=0 ;	  
				for (k=0;k<32;k++) {
					if ((v>>k)&1) {
						f = 1;
					} else if (f==1) {
						return false ;
					}
				}
				if (f==0) { 
					return false;
				}
			
				for(i = 0; i < 4; i++) {
					var t=/^\d{1,}$/;
					if(!t.test(mn[i])) {
						return false;
					}	
				}
				
				return true ;
			},
			message: "请正确输入掩码."
		},
		"ip_mac":{
			method:function(val){
				var ip_reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				var mac_reg = /^([0-9a-fA-F]{2}(:|-)){5}[0-9a-fA-F]{2}$/;
				var ipmac_reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/([0-9a-fA-F]{2}(:|-)){5}[0-9a-fA-F]{2}$/;
				var reg_s = /\S/;
				val = val.trim();
				var arr = val.split('\n');
				for(var k = 0; k<arr.length; k++){
					if(ip_reg.test(arr[k]) || mac_reg.test(arr[k]) || ipmac_reg.test(arr[k])){
						
					}else{
						return false;	
					}	
				}
				return true;
			},
			message:"非法ip地址或MAC地址"	
		},
		"num": {
			method: function(val, from, to){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				if (from && to) {
					return (parseInt(val) >= parseInt(from) && parseInt(val) <= parseInt(to));
				};
				return true;
			},
			message: "非法数字格式"
		},
		"nums": { //可以为负数
			method: function(val, from, to){
				var re = /^-?[1-9]\d*$/;
				if (!val.match(re)) {
					return false;
				};
				if (from && to) {
					return (parseInt(val) >= parseInt(from) && parseInt(val) <= parseInt(to));
				};
				return true;
			},
			message: "非法数字格式"
		},　
		"url": {
			method: function(url){
				var strRegex = "^((https|http|ftp|rtsp|mms)?://)"       
                    + "?(([0-9a-zA-Z_!~*'().&=+$%-]+: )?[0-9a-zA-Z_!~*'().&=+$%-]+@)?" //ftp的user@      
                    + "(([0-9]{1,3}\.){3}[0-9]{1,3}" // IP形式的URL- 199.194.52.184      
                    + "|" // 允许IP和DOMAIN（域名）      
                    + "([0-9a-zA-Z_!~*'()-]+\.)*" // 域名- www.      
                    + "([0-9a-zA-Z][0-9a-zA-Z-]{0,61})?[0-9a-zA-Z]\." // 二级域名      
                    + "[a-zA-Z]{2,6})" // first level domain- .com or .museum      
                    + "(:[0-9]{1,4})?" // 端口- :80      
                    + "((/?)|"       
                    + "(/[0-9a-zA-Z_!~*'().;?:@&=+$,%#-]+)+/?)$"; 			
				var re=new RegExp(strRegex);
				url = url.trim();
				var arr = url.split('\n');
				for(var k = 0; k<arr.length; k++){
					if (re.test(arr[k])){
						//
					}else{
						return false;
					}
				}
				return true;
			},
			message: "非法ip地址"
		},
		"regexp": {
			method: function(val, exp){
				return val.match(RegExp(exp))!=null;
			},
			message: "非法格式"
		},
		"notspace": {
			method: function(val){
				return $.trim(val)!=""?true:false;
			},
			message:"不能为空."
		},	  
		"name":{
			method:function(val){
				var reg1 = /^[a-zA-Z0-9- _.\u4e00-\u9fa5]{2,32}$/;
				return (reg1.test(val))?true:false;
			},
			message:"非法格式.名字只能包含数字、字母、‘-’、‘.’ 和下划线.长度范围2~32."				
		},
		"apname":{
			method:function(val){
				var reg1 = /^[a-zA-Z0-9- _.\u4e00-\u9fa5]{0,32}$/;
				return (reg1.test(val))?true:false;
			},
			message:"请正确输入AP描述名."				
		},
		"ssid":{
			method:function(val){
				var len = 0;
				for (var i=0; i<val.length; i++) {
					var c = val.charCodeAt(i);
					//单字节加1
					if ((c >= 0x0001 && c <= 0x007e) || (0xff60 <= c && c <= 0xff9f)) {
						len++;
					}
					else {
						len += 3;
					}
				}
				var reg1 = /^[a-zA-Z0-9- _.\u4e00-\u9fa5]{1,32}$/;
				var mark = (reg1.test(val))?true:false;
				if (len <= 32 && mark) {
					return true;
				} else {
					return false;
				}
			},
			message:"请正确输入SSID."				
		},
		"pptp":{
			method:function(val){
				var reg1 = /^[a-zA-Z0-9_]{2,32}$/;
				return (reg1.test(val))?true:false;
			},
			message:"非法格式.名字只能包含数字、字母、‘-’、‘.’ 和下划线.长度范围2~32. "
				
		},		
		"pwd": {
			method: function(val){
				var re = /^[0-9a-zA-Z_]{1,15}$/i;
				return val.match(re)!=null;
			},
			message: "非法格式.名字只能包含数字、字母和下划线.长度范围3~15"
		},
		"email": {
			method: function(email){
			var arr = ["ac","com","net","cn","org","edu","gov","mil","ac\.cn","com\.cn","edu\.cn","net\.cn","org\.cn"],
				tempStr = arr.join("|"),
				regStr = "^[0-9a-zA-Z](\\w|-)*@\\w+\\.(" + tempStr + ")$",
				regExp = new RegExp(regStr);
				
			return regExp.test(email)?true:false;
			},
			message: "非法邮件地址"
		},
		"email2": {
			method: function(email){
			var arr = ["ac","com","net","cn","org","edu","gov","mil","ac\.cn","com\.cn","edu\.cn","net\.cn","org\.cn"],
				tempStr = arr.join("|"),
				regStr = "^([0-9a-zA-Z](\\w|-)*@\\w+\\.(" + tempStr + "))(\;[0-9a-zA-Z](\\w|-)*@\\w+\\.(" + tempStr + "))*$",
				regExp = new RegExp(regStr);
				
			return regExp.test(email)?true:false;
			},
			message: "非法格式, 多个邮件地址应用逗号隔开."
		},
		"numcycle": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 300);
			},
			message: "请正确输入信道扫描周期."
		},
		"numtime": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 10 && parseInt(val) <= 300);
			},
			message: "请正确输入单信道扫描时间."
		},
		"numvlan": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 4096);
			},
			message: "请正确输入VLANID."
		},
		"num2g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 5 && parseInt(val) <= 50);
			},
			message: "请正确输入2G的最大用户数."
		},
		"num5g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 5 && parseInt(val) <= 50);
			},
			message: "请正确输入5G的最大用户数."
		},
		"rts2g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 2347);
			},
			message: "请正确输入2G的RTS阈值."
		},
		"rts5g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 2347);
			},
			message: "请正确输入5G的RTS阈值."
		},
		"beacon2g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 50 && parseInt(val) <= 1000);
			},
			message: "请正确输入2G的Beacon周期."
		},
		"beacon5g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 50 && parseInt(val) <= 1000);
			},
			message: "请正确输入5G的Beacon周期."
		},
		"dtim2g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 100);
			},
			message: "请正确输入2G的DTIM间隔."
		},
		"dtim5g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 100);
			},
			message: "请正确输入5G的DTIM间隔."
		},
		"remax2g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 10);
			},
			message: "请正确输入2G的最大重传."
		},
		"remax5g": {
			method: function(val){
				var re = /^[0-9]{1,}$/;
				if (!val.match(re)) {
					return false;
				};
				return (parseInt(val) >= 1 && parseInt(val) <= 10);
			},
			message: "请正确输入5G的最大重传."
		},
		"wpassword": {
			method: function(val){
				var reg1 = /^[a-z|0-9|A-Z]{8,32}$/;
				return (reg1.test(val))?true:false;
			},
			message: "请正确输入无线密码."
		}
	};

	function getVerifyObject(id){
		var vo = VerifyImplication[id];
		if (typeof(vo) == "object" && vo.method ) {
			return vo;
		}else{
			return null;
		}
	};

	function getVerfiyPars(o) {
		var verify = o.attr('verify');
		if (typeof(verify) != "string") {
			return null;
		}
		return verify.split(' ');
	}

	//直接显示调用
	var verification = function(c) {
		var res = true;
		if (!c) c = "body";
		$('input,textarea', c).each(function(){
			if ( $(this).attr("disabled") == "disabled" ) return true;
			var val = $(this).val();
			var pars = getVerfiyPars($(this));
			if (!pars || pars.length < 1) {
				return true;
			};
			var vo = getVerifyObject(pars[0]);
			if (vo && vo.method) {
				pars[0] = val;
				//if(val != ''){
					res = vo.method.apply(this, pars);
				//}
				if (res!=true) {
					/*
					if ($(this).hasClass('invalid')) {
						alert('请处理红色错误格式！');
						return false;
					}
					*/
					$(this).addClass('invalid');
					alert(vo.message);
					if (vo.message) {
						if($('#messages')){
							//$('#messages').html(vo.message);
						}
					};
					return false;
				}else{
					$(this).removeClass('invalid');
				}
			};
			return true;
		});
		if (res) {
			if($('#messages')){
				$('#messages').html("");
			}
		};
		return res;
	}

	//事件绑定触发方式调用
	var verifyEventsInit = function() {
		$('input,textarea').each(function() {
			var input = $(this);
			var pars = getVerfiyPars($(this));
			if (!pars || pars.length < 1) {
				return true;
			};
			var vo = getVerifyObject(pars[0]);
			if (!vo) {
				return true;
			};
			//bind
			input.on('change', function() {
				pars[0] = $(this).val();
				var res = vo.method.apply(this, pars);
				if (res!=true && pars != '') {
					//验证失败
					$(this).addClass('invalid');
					alert(vo.message);
				}else{
					$(this).removeClass('invalid');
				}
			});
			return true;
		});
	}

	root.verification = verification;
	root.verifyEventsInit = verifyEventsInit;
}(window, undefined);

function fncheckVal(){
	var flag = 1
	var val_reg = /^(((0\d{2,3})-)?(\d{7,8})(-(\d{3,}))?)?$/;
	$(".cont").each(function(){
		var val = $(this).val();
		if(val_reg.test(val)){
			flag = 0;
			return flag;
		}
	})
	return flag;
		
}


