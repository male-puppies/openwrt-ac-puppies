(function(root, undefined) {

	var cgicall = (function() {
		var version = "/v1/",
			token = $.cookie("token") ? "&token=" + $.cookie("token") : "",
			callfn = function(d, x, s) {},
			callback = function(d, x, s) {
				if (typeof d != "undefined" && typeof d.status != "undefined" && typeof d.data != "undefined" && d.status == 1 && d.data.indexOf("timeout") > -1) {
					window.location.href = "/admin/view/admin_login/login.html";
				}
				callfn(d, x, s);
			};
		
		function get() {
			var obj,
				url,
				objstr,
				argc = arguments.length;

			callfn = function(d, x, s) {};
			if (typeof(arguments[argc - 1]) === "function") {
				argc = argc - 1;
				callfn = arguments[argc];
			}
			
			if (argc == 2 && Object.prototype.toString.call(arguments[1]) === '[object Object]') {
				for (var k in arguments[1]) {
					objstr += "&" + k + "=" + arguments[1][k];
				}
			} else {
				objstr = "";
			}
			
			url = version + "admin/api/" + arguments[0] + "?_=" + new Date().getTime() + token + objstr;

			$.get(url, callback, "json");
		}
		
		function post() {
			var obj,
				url,
				argc = arguments.length;

			callfn = function(d, x, s) {};
			if (typeof(arguments[argc - 1]) === "function") {
				argc = argc - 1;
				callfn = arguments[argc];
			}
			
			if (argc == 2 && typeof arguments[1] == "object") {
				obj = arguments[1]
			} else {
				obj = {}
			}
			
			url = version + "admin/api/" + arguments[0] + "?_=" + new Date().getTime() + token;
			
			$.post(url, obj, callback, "json");
		}
		
		return {
			"get": get,
			"post": post
		}
	}())
	
	function jsonTraversal(obj, func) {
		var oset = ObjClone(obj);
		for (var k in oset) {
			if (typeof(oset[k]) == 'object') {
				oset[k] = recurseTravSubNode(oset[k], k, func);
			} else {
				var fp = k;
				oset[k] = func(fp, oset[k]);
			}
		}
		return oset;
	}
	
	//遍历所有节点
	function recurseTravSubNode(o, parent, func) {
		var oset = ObjClone(o);
		for (var k in o) {
			var fp = parent + '__' + k;
			if (typeof(o[k]) == 'object') {
				//还有子节点.
				oset[k] = recurseTravSubNode(o[k], fp, func);
			} else {
				oset[k] = func(fp, o[k]);
			}
		}
		return oset;
	}
	
	
	/*
		********
		需要特殊处理的控件:checkbox, radio
		不需要特殊处理的:text, texterea, select,
		*********
	*/
	function jsTravSet(fp, v) {
		var doc = getControlByIdMisc(fp),
			type = doc.attr('type');
		
		switch (type) {
			case "checkbox":
				var arr = doc.val().split(" ");
				var str = v.toString();
				
				if (str == arr[0]) {
					doc.prop("checked", true);
				} else {
					doc.prop("checked", false);
				}
				break;

			case "radio":
				var that = doc.attr("name");
				$('input:radio[name="'+ that +'"]').each(function(index, element) {
					if ($(element).val() == v) {
						$(element).prop("checked", true);
					} else {
						$(element).prop("checked", false);
					}
				});
				break;

			default:
				doc.val(v);
				break;
		}

		return v;
	}

	function jsTravGet(fp, v){
		var nv,
			doc = getControlByIdMisc(fp),
			type = doc.attr('type');

		switch (type) {
			case 'checkbox':
				var arr = doc.val().split(" ");
				var str = v.toString();
				

				if (arr.length == 1) {
					if (arr[0] == "1") {
						arr[1] = "0";
					} else if (arr[0] == "true") {
						arr[1] = "false";
					} else {
						console.log(fp + 'checkbox value fail');
					}
				}
				
				if (typeof v == "boolean") {
					arr[0] = true;
					arr[1] = false;
				} else if (typeof v == "number") {
					arr[0] = parseInt(arr[0]);
					arr[1] = parseInt(arr[1]);
				}

				nv = doc.is(":checked") ? arr[0] : arr[1];
				break;

			case 'radio':
				var that = doc.attr("name");
				nv = $('input:radio[name="'+ that +'"]:checked').val();
				if (typeof v == "number") {
					nv = parseInt(nv);
				}
				break;

			default:
				nv = doc.val();
				break;
		}

		nv = (typeof(nv) == 'undefined' ? v : nv);

		if (typeof(v) == 'number') {
			nv = parseInt(nv);
		};
		return nv;
	}


	function getControlByIdMisc(id){
		//优先尝试input类型,其次select,再次ID.
		var id = id.replace(/\//g, '-'),
			id = id.replace(/\:/g, '_');
			res = $('input#' + id);

		if (res.length < 1) {
			res = $('select#' + id);
		}
		if (res.length < 1) {
			res = $('#' + id);
		};
		return res;
	}
	
	function ObjClone(obj) {
		var o;
		if (typeof obj == "object") {
			if (obj === null) {
				o = null;
			} else {
				if (obj instanceof Array) {
					o = [];
					for (var i = 0, len = obj.length; i < len; i++) {
						o.push(ObjClone(obj[i]));
					}
				} else {
					o = {};
					for (var j in obj) {
						o[j] = ObjClone(obj[j]);
					}
				}
			}
		} else {
			o = obj;
		}
		return o;
	}
	
	function createModalTips(tip, e) {
		$("#modal_tips .modal-p span").html(tip);
		$("#modal_tips .modal-footer .btn-modal").remove();
		
		if (typeof(e) != "undefined") {
			var input = '<input type="button" class="btn btn-zx btn-modal" onclick="' + e + '()" value="确定" />';
			$("#modal_tips .modal-footer").append(input);
		}
		$("#modal_tips").modal("show");
	}
	
	function setUrlParam(src, key, val) {
		var reg = eval('/(' + key + '=)([^&]*)/gi');
		var nUrl = src.replace(reg, key + '=' + val);
		return nUrl;
	}
	
	function getUrlParam(src, val) {
		var reg = new RegExp("(^|\\?|&)" + val + "=([^&#]*)(\\s|&|$|#)", "i");
		if (reg.test(src)) return unescape(RegExp.$2); 
		return "";
	}
	
	root.jsonTraversal		= jsonTraversal;			//取值赋值入口
	root.jsTravGet			= jsTravGet;				//取值
	root.jsTravSet			= jsTravSet;				//赋值
	
	root.ObjClone			= ObjClone;
	root.createModalTips	= createModalTips;			//创建提示模态框
	
	root.cgicall			= cgicall;
	root.setUrlParam		= setUrlParam;
	root.getUrlParam		= getUrlParam;
})(this);