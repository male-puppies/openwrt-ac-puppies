(function(root, undefined) {

	var VerifyImplication = {
		"ip": {
			method: function(val) {
				var reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				return (reg.test(val)) ? true : false;
			},
			message: "非法IP格式。"
		},
		"mask": {
			method: function(val) {
				var reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				if (!reg.test(val)) {
					return false;
				}
				var m = [],
					mn = val.split(".");
				
				if (val == "0.0.0.0" || val == "255.255.255.255"){
					return true;
				}
				if (mn.length == 4) {
					for (i = 0; i < 4; i++) {
						m[i] = mn[i];
					}
				} else {
					return false;
				}
			
				var v = (m[0]<<24)|(m[1]<<16)|(m[2]<<8)|(m[3]);
			
				var f = 0;	  
				for (k = 0; k < 32; k++) {
					if ((v >> k) & 1) {
						f = 1;
					} else if (f == 1) {
						return false ;
					}
				}
				if (f == 0) { 
					return false;
				}
			
				for(i = 0; i < 4; i++) {
					var t = /^\d{1,}$/;
					if(!t.test(mn[i])) {
						return false;
					}	
				}
				
				return true ;
			},
			message: "非法掩码格式。"
		},
		"lan_mask": {
			method: function(val) {
				var reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				if (!reg.test(val)) {
					return false;
				}
				var m = [],
					mn = val.split(".");
				
				if (val == "0.0.0.0" || val == "128.0.0.0" || val == "192.0.0.0" || val == "224.0.0.0" || val == "240.0.0.0" || val == "248.0.0.0" || val == "252.0.0.0" || val == "254.0.0.0") {
					return false;
				}
				if (val == "255.255.255.255"){
					return true;
				}
				if (mn.length == 4) {
					for (i = 0; i < 4; i++) {
						m[i] = mn[i];
					}
				} else {
					return false;
				}
			
				var v = (m[0]<<24)|(m[1]<<16)|(m[2]<<8)|(m[3]);
			
				var f = 0;	  
				for (k = 0; k < 32; k++) {
					if ((v >> k) & 1) {
						f = 1;
					} else if (f == 1) {
						return false ;
					}
				}
				if (f == 0) { 
					return false;
				}
			
				for(i = 0; i < 4; i++) {
					var t = /^\d{1,}$/;
					if(!t.test(mn[i])) {
						return false;
					}	
				}
				
				return true ;
			},
			message: "非法掩码格式。"
		},
		"ips":{
			method: function(val) {
				var ip_reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				var ips_reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;

				var arr = val.split('\n');
				for (var k = 0; k < arr.length; k++) {
					if (!(ip_reg.test(arr[k]) || ips_reg.test(arr[k]))) {
						return false;
					}
					
					if (ips_reg.test(arr[k])) {
						var ips = arr[k].split('-');
						var arr1 = ips[0].split('.');
						var arr2 = ips[1].split('.');
						for (var i = 0; i < arr1.length; i++) {
							if (parseInt(arr1[i]) > parseInt(arr2[i])) {
								return false;
							} else if (parseInt(arr1[i]) < parseInt(arr2[i])) {
								break;
							}
						}
					}
				}
				return true;
			},
			message: "非法IP格式。"	
		},
		"ipss":{
			method: function(val) {
				var ips_reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)-(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;

				if (!ips_reg.test(val)) {
					return false;
				}
				
				if (ips_reg.test(val)) {
					var ips = val.split('-');
					var arr1 = ips[0].split('.');
					var arr2 = ips[1].split('.');
					console.log(arr1)
					console.log(arr2)
					for (var i = 0; i < arr1.length; i++) {
						if (parseInt(arr1[i]) > parseInt(arr2[i])) {
							return false;
						} else if (parseInt(arr1[i]) < parseInt(arr2[i])) {
							break;
						}
					}
				}
				return true;
			},
			message: "非法IP范围。"	
		},
		"mac": {
			method: function(val) {
				var reg = /^([0-9a-fA-F]{2}(:)){5}[0-9a-fA-F]{2}$/;
				return (reg.test(val)) ? true : false;
			},
			message: "非法MAC格式。"
		},
		"macsp": {
			method: function(val) {
				if (val == "") return true;
				var reg = /^([0-9a-fA-F]{2}(:)){5}[0-9a-fA-F]{2}$/;
				return (reg.test(val)) ? true : false;
			},
			message: "非法MAC格式。"
		},
		"macs": {
			method: function(val) {
				var reg = /^([0-9a-fA-F]{2}(:)){5}[0-9a-fA-F]{2}$/;

				var arr = val.split('\n');
				for (var k = 0; k < arr.length; k++) {
					if (!reg.test(arr[k])) {
						return false;
					}
				}
				return true;
			},
			message: "非法MAC格式。"
		},
		"dns": {
			method: function(val) {
				var reg = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
				
				var arr = val.split(',');
				for (var k = 0; k < arr.length; k++) {
					if (!reg.test(arr[k])) {
						return false;
					}
				}
				return true;
			},
			message: "非法DNS格式。"
		},
		"num": {
			method: function(val, from, to) {
				var reg = /^-?[0-9]\d*$/;
				if (!reg.test(val)) return false;
				if (from && to) return (parseInt(val) >= parseInt(from) && parseInt(val) <= parseInt(to));
				return true;
			},
			message: "非法数字格式。"
		},
		"numsp": {
			method: function(val, from, to) {
				if (val == "") return true;
				var reg = /^-?[0-9]\d*$/;
				if (!reg.test(val)) return false;
				if (from && to) return (parseInt(val) >= parseInt(from) && parseInt(val) <= parseInt(to));
				return true;
			},
			message: "非法数字格式。"
		},
		"notspace": {
			method: function(val) {
				return $.trim(val) != "" ? true : false;
			},
			message: "非法格式。不能为空。"
		},
		"strlen": {
			method: function(val, from, to) {
				if (typeof to == "undefined") {
					return $.trim(val).length == parseInt(from) ? true : false;
				} else {
					if ($.trim(val).length >= parseInt(from) && $.trim(val).length <= parseInt(to)) {
						return true;
					} else {
						return false;
					}
				}
			},
			message: "非法格式。"
		},
		"name": {
			method: function(val) {
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
				var reg = /^[a-zA-Z0-9-_.\u4e00-\u9fa5]{1,32}$/;
				var mark = (reg.test(val)) ? true : false;
				if (len <= 32 && mark) {
					return true;
				} else {
					return false;
				}
			},
			message:"非法格式。只能包含中文、数字、字母、‘-’、‘.’ 和下划线，不允许空格。长度范围1~32个字符，不超过10个中文。"				
		},
		"ssid_name": {
			method: function(val) {
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
				var reg = /^[a-zA-Z0-9-_.!@#\u4e00-\u9fa5]{1,32}$/;
				var mark = (reg.test(val)) ? true : false;
				if (len <= 32 && mark) {
					return true;
				} else {
					return false;
				}
			},
			message:"非法格式。只能包含中文、数字、字母、‘-’、‘.’ 和下划线，不允许空格。长度范围1~32个字符，不超过10个中文。"				
		},
		"pwd": {
			method: function(val) {
				var reg = /^[0-9a-zA-Z_]{4,32}$/;
				return (reg.test(val)) ? true : false;
			},
			message: "非法格式。只能包含数字、字母和下划线。长度范围4~32个字符。"
		},
		"ssid": {
			method: function(val){
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
				var reg = /^[a-zA-Z0-9-_.\u4e00-\u9fa5]{1,32}$/;
				var mark = (reg.test(val)) ? true : false;
				if (len <= 32 && mark) {
					return true;
				} else {
					return false;
				}
			},
			message: "非法格式。不能为空，输入字符串长度小于32个字符，不超过十个中文。"				
		},
		"desc": {
			method: function(val){
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
				var reg = /^[a-zA-Z0-9- _.\u4e00-\u9fa5]{0,32}$/;
				var mark = (reg.test(val)) ? true : false;
				if (len <= 32 && mark) {
					return true;
				} else {
					return false;
				}
			},
			message: "非法格式。输入字符串长度小于32个字符，不超过十个中文。"				
		},
		"wpassword": {
			method: function(val) {
				var reg = /^[a-z|0-9|A-Z]{8,32}$/;
				return (reg.test(val)) ? true : false;
			},
			message: "非法格式。输入数字/字母，长度: 8~32个字符。"
		},
		"upload": {
			method: function() {
				if (!(typeof arguments[0] != "undefined" && arguments[0] != "")) return false;
				
				var arr = arguments[0].split(".");
				if (arr.length < 2) return false;
				var str = arr[arr.length - 1];
				var mark = false;
				for (var i = 1; i < arguments.length; i++) {
					if (str == arguments[i]) {
						mark = true;
					}
				}
				
				if (mark == true) {
					return true;
				} else {
					return false;
				}
			},
			message: "上传文件格式非法。"
		}
	}

	function getVerifyObject(key){
		var obj = VerifyImplication[key];
		if (typeof(obj) == "object" && obj.method) {
			return obj;
		} else {
			return null;
		}
	}

	function getVerfiyPars(doc, fla) {
		var verify = doc.attr('verify');
		if (doc.is(":disabled") && typeof fla == "undefined") {
			doc.closest(".form-group").removeClass('has-error');
			return null;
		}
		if (typeof(verify) != "string") {
			return null;
		}
		return verify.split(' ');
	}

	var verification = function(doc) {
		var res = true;
		if (!doc) doc = "body";

		$('input,textarea', doc).each(function() {
			var key,
				pars,
				obj;

			pars = getVerfiyPars($(this));
			if (!pars || pars.length < 1) {
				return true;
			}

			key = pars[0];
			obj = getVerifyObject(key);

			if (obj && obj.method) {
				pars[0] = $(this).val();
				res = obj.method.apply(this, pars);
				if (res != true) {
					var tip = $(this).closest(".form-group").find("label.control-label").html() || "";
					$(this).closest(".form-group").addClass('has-error');
					
					verifyModalTip(tip, obj.message);
					return false;
					// var hmark = true;
					// var hid = "";
					// $("body > .modal").each(function(index, element) {
						// if ($(element).is(":visible")) {
							// hmark = false;
							// hid = $(element).attr("id");
							// return false;
						// }
					// });

					// if (hmark && $("body > .modal-backdrop").length == 0 && Object.prototype.toString.call(createModalTips) === "[object Function]") {
						// createModalTips(tip + " " + obj.message);
					// } else if (typeof hid != "undefined" && hid != "" && $("#" + hid + " .modal-footer .tip").length > 0) {
						// console.log($("#" + hid + " .modal-footer .tip").length)
						// $("#" + hid + " .modal-footer .tip").html("<span title='" + tip + " " + obj.message + "'><i class='icon-remove-sign'></i> " + tip + " " + obj.message + "</span>");
					// } else {
						// alert(tip + " " + obj.message);
					// }
					// return false;
				} else {
					$(this).closest(".form-group").removeClass('has-error');
				}
			}
		});

		return res;
	}
	
	var verifyModalTip = function(h, t) {
		var tips;
		if (typeof h == "undefined") return false;
		if (typeof t != "undefined") {
			tips = h + " " + t;
		} else {
			tips = h;
		}
		
		var hmark = true;
		var hid = "";
		$("body > .modal").each(function(index, element) {
			if ($(element).is(":visible")) {
				hmark = false;
				hid = $(element).attr("id");
				return false;
			}
		});

		if (hmark && $("body > .modal-backdrop").length == 0 && Object.prototype.toString.call(createModalTips) === "[object Function]") {
			createModalTips(tips);
		} else if (typeof hid != "undefined" && hid != "" && $("#" + hid + " .modal-footer .tip").length > 0) {
			$("#" + hid + " .modal-footer .tip").html("<span title='" + tips + "'><i class='icon-remove-sign'></i> " + tips + "</span>");
		} else {
			alert(tips);
		}
		return false;
	}

	var verifyEventsInit = function(doc) {
		var res = true;
		var hid = "";
		if (!doc) doc = "body";

		$("input[type='radio'], input[type='checkbox'], select", doc).on("change", function() {
			var that = this;
			setTimeout(function() {
				$(that).closest("form").find("input, textarea").each(function(index, element) {
					if ($(element).is(":disabled") && $(element).closest(".form-group").length > 0 && $(element).closest(".form-group").hasClass("has-error")) {
						$(element).closest(".form-group").removeClass("has-error");
						getHid();
						rmModaltip($(element));
					}
				});
			}, 150);
		});

		$('input, textarea', doc).each(function() {
			var key,
				pars,
				obj,
				that = this;

			pars = getVerfiyPars($(that), true);
			if (!pars || pars.length < 1) {
				return true;
			}

			key = pars[0];
			obj = getVerifyObject(key);
			if (obj && obj.method) {
				$(that).on("blur keyup", function(e) {
					if (e.type == "keyup" && !$(that).closest(".form-group").hasClass("has-error")) return false;
					pars[0] = $(that).val();
					res = obj.method.apply(that, pars);
					if (res != true) {
						$(that).closest(".form-group").addClass('has-error');
					} else {
						$(that).closest(".form-group").removeClass('has-error');
						getHid();
						rmModaltip($(that));
					}
				});
			}
		});
		
		function getHid() {
			$("body > .modal").each(function(index, element) {
				if ($(element).is(":visible")) {
					hid = $(element).attr("id");
					return false;
				}
			});
		}

		function rmModaltip(el) {
			if (hid != "") {
				var that = $("#" + hid + " .modal-footer .tip");
				if (that.length > 0) {
					var tip = el.closest(".form-group").find("label.control-label").html();
					var tip2 = that.html();
					if (tip2.indexOf(tip) > 0) {
						that.html("");
					}
				}
			}
		}
	}

	root.verification = verification;			//直接显示调用
	root.verifyEventsInit = verifyEventsInit;	//事件绑定触发方式调用
	root.verifyModalTip = verifyModalTip;		//alert提示
})(this);