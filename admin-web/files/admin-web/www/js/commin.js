(function(root, undefined) {
	
	function cgicall() {
		var url = "/call/cgicall",
			obj = {},
			argc = arguments.length,
			callback = function(d, x, s) {};

		if (typeof(arguments[argc - 1]) === "function") {
			argc = argc - 1;
			callback = arguments[argc];
		}

		switch(argc) {
			case 1:
				if (typeof(arguments[0]) === "string") {
					obj["key"] = arguments[0];
				} else {
					console.log("error cgicall...")
				}
				break;
			case 2:
				obj["key"] = arguments[0];
				obj["data"] = arguments[1];
				break;
			default:
				console.log("error cgicall...")
				break;
		}

		var cmdObj = {
			"cmd": JSON.stringify(obj)
		};
		// $.post(url, cmdObj, callback, "json");
		$.post(url, cmdObj, function(d, x, s) {
			if (typeof d != "undefined" && typeof d.status != "undefined" && typeof d.data != "undefined") {
				if (d.status == 1 && d.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				}
			}
			callback(d, x, s);
			
		}, "json");
	}
	
	function cgicallBack() {
		var argc = arguments.length;
		var sfunc = function() {};
		var ffunc = function() {};

		if (typeof(arguments[argc - 1]) === "object") {
			argc = argc - 1;
			if ("sfunc" in arguments[argc]) {
				sfunc = arguments[argc]["sfunc"];
			}
			if ("ffunc" in arguments[argc]) {
				ffunc = arguments[argc]["ffunc"];
			}
		}

		switch(argc) {
			case 2:
				if (typeof(arguments[0]) === "object" && typeof(arguments[1]) === "string") {
					if (arguments[0].status == 0) {
						$(arguments[1]).modal("hide");
						$(arguments[1]).one("hidden.bs.modal", sfunc);
					} else {
						$(arguments[1]).modal("hide");
						$(arguments[1]).one("hidden.bs.modal", ffunc);
					}
				} else {
					console.log("error cgicallBack...")
				}
				break;
			default:
				if (typeof(arguments[0]) === "object") {
					if (arguments[0].status == 0) {
						sfunc();
					} else {
						ffunc();
					}
				} else {
					console.log("error cgicallBack...")
				}
				break;
		}
	}
	
	function ucicall() {
		var url = "/call/ucicall",
			obj = {},
			argc = arguments.length,
			callback = function(d, x, s) {};

		if (typeof(arguments[argc - 1]) === "function") {
			argc = argc - 1;
			callback = arguments[argc];
		}

		switch(argc) {
			case 1:
				if (typeof(arguments[0]) === "string") {
					obj["key"] = arguments[0];
				} else {
					console.log("error cgicall...")
				}
				break;
			case 2:
				obj["key"] = arguments[0];
				obj["data"] = arguments[1];
				break;
			default:
				console.log("error cgicall...")
				break;
		}

		var cmdObj = {
			"cmd": JSON.stringify(obj)
		};
		// $.post(url, cmdObj, callback, "json");
		$.post(url, cmdObj, function(d, x, s) {
			if (typeof d != "undefined" && typeof d.status != "undefined" && typeof d.data != "undefined") {
				if (d.status == 1 && d.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				}
			}
			callback(d, x, s);
			
		}, "json");
	}
	
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
	
	function ObjCountLength(o) {
		var t = typeof o;
		if (t == 'string') {
			return o.length;
		} else if (t == 'object') {
			var n = 0;
			for (var i in o) {
				n++;
			}
			return n;
		}
		return false;
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
	
	function dtObjToArray(o) {
		var arr = [],
			obj = ObjClone(o);

		if (typeof obj == 'object') {
			if (Object.prototype.toString.call(obj) === '[object Array]') {
				arr = obj;
			} else if (Object.prototype.toString.call(obj) === '[object Object]') {
				for (key in obj) {
					arr.push(obj[key]);
				}
			} else {
				arr.push(obj);
			}
		} else {
			arr.push(obj);
		}
		return arr;
    }
	
	function dtReloadData(table, bool, func) {
		var callback = null;
		if (typeof func == "function") {
			callback = func;
		}
		table.api().ajax.reload(callback, bool);	//false 保存分页
    }
	
	function dtRrawData(table, data) {
		table.api().clear();
		if (ObjCountLength(data) == 0) return;
		table.api().rows.add(dtObjToArray(data)).draw();
	}
	
	function dtHideColumn(table, hd) {
		table.api().columns().visible(true);
		for (var i = 0; i < hd.length; i++) {
			var num = parseInt(hd[i]);
			if (num < 0) continue;
			var column = table.api().column(num);
			column.visible(false);
		}
	}
	
	function dtGetSelected(table) {
		var arr = [];
		var drows = table.api().rows(".row_selected").data();
		for (var i = 0; i < drows.length; i++) {
			arr.push(drows[i])
		}
		return arr;
    }

	function dtSelectAll(that, table, currentPage) {
		var check = $(that).is(":checked");
        if (currentPage) {
            var drows = table.api().rows().nodes();
            for (var i = 0; i < drows.length; i++) {
				var _this = $(drows[i]);
				if (_this.find('td input[type="checkbox"]').is(":disabled")) continue;
                _this.find('td input[type="checkbox"]').prop("checked", check);
				row_select_event(_this);
            };
        } else {
			//默认只选中当前显示部分，后台分页时无法获取数据
			table.find('tbody tr').each(function(index, element) {
                var row = $(element);
				if (row.find('td input[type="checkbox"]').is(":disabled")) return true;
                row.find('td input[type="checkbox"]').prop("checked", check);
				row_select_event(row);
            });
        }
    }
	
    function dtBindRowSelectEvents(row) {
		var that = $(row);
		that.find('td input[type="checkbox"]').off('click', function() {
			row_select_event(that)
		});
        that.find('td input[type="checkbox"]').on('click',  function() {
			row_select_event(that)
		});
    }
	
	function row_select_event(that) {
		if (that.find('td input[type="checkbox"]').is(":checked")) {
			that.addClass("row_selected");
		} else {
			that.removeClass("row_selected");
		}
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

	/* cgi */
	root.cgicall =					cgicall;				//post
	root.cgicallBack = 				cgicallBack;			//cgicall回调
	root.ucicall =					ucicall;
	root.jsonTraversal =			jsonTraversal;			//取值赋值入口
	root.jsTravGet =				jsTravGet;				//取值
	root.jsTravSet =				jsTravSet;				//赋值
	
	/* object */
	root.ObjCountLength =			ObjCountLength;			//对象长度
	root.ObjClone =					ObjClone;				//对象克隆
	root.createModalTips =			createModalTips;		//创建提示模态框
	
	/* datatable */
	root.dtObjToArray =				dtObjToArray;			//对象强制转数组 去适应datatable
	root.dtReloadData =				dtReloadData;			//刷新datatable
	root.dtRrawData =				dtRrawData;				//重绘datatable
	root.dtHideColumn =				dtHideColumn;			//隐藏datatable列
	root.dtGetSelected =			dtGetSelected;			//获取datatable选中的列
	root.dtSelectAll =				dtSelectAll;			//选中所有datatable列
	root.dtBindRowSelectEvents = 	dtBindRowSelectEvents;	//绑定选择事件
})(this);

$(function() {
	$("table.table").on("mouseover", "tbody tr", function() {
		$(this).addClass("highlight");
		$(this).siblings("tr").removeClass("highlight");
	})
	.on("mouseleave", "tbody tr", function() {
		$(this).removeClass("highlight");
	});
	
	$("body > .modal").on("hidden.bs.modal", function() {
		$(".has-error", this).removeClass("has-error");
		$(".modal-footer .tip", this).html("");
	})
});
