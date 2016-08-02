var oTabUser,
	modify_flag = "add",
	nodeEdit = [],
	g_user = {
		enable: 1,
		name: '',
		pwd: '',
		desc: '',
		multi: 1,
		bind: '',
		expire: '',
		remain: ''
	};

$(function(){
	oTabUser = createDtUser();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtUser() {
	var cmd = {"key": "UserGet"}
	return $("#table_groupuser").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/black/dataTables.chinese.json'},
		"ajax": {
			"url": "/call/cgicall",
			"type": "POST",
			"data": {
				"cmd": JSON.stringify(cmd)
			},
			"dataSrc": function(json) {
				if (json.status == 0) {
					return dtObjToArray(json.data);
				} else if (json.data == "login") {
					window.location.href = "/login/admin_login/login.html";
				} else {
					return [];
				}
			}
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
            {
				"data": "name",
            	"render" : function(d, t, f) {
					if (f.desc != "") {
						d = d + '(' + f.desc + ')';
					}
					return d;
            	}
            },
            {
				"data": "maclist",
            	"render": function (d, t, f) {
					var str;
					if (f.bind == "none") {
						str = "无";
					} else {
						if (dtObjToArray(d).length == 0) {
							str = "无";
						} else {
							str = dtObjToArray(d).join("</br>");
						}
					}
					return str;
               }
            },
			{
				"data": "expire",
				"render": function (d, t, f) {
					if (typeof d != "undefined") {
						if (d[0] == 0) {
							return "永久有效";
						} else {
							var data = d[1];
							return data.substring(0,4) + "/" + data.substring(4,6) + "/" + data.substring(6,8) + " " + data.substring(9,11) + ":" + data.substring(11,13) + ":" + data.substring(13);
						}
					} else {
						return "永久有效";
					}
               }
			},
			{
				"data": "remain",
				"render": function (d, t, f) {
			  		if (typeof d != "undefined") {
						if (d[0] == 0) {
							return "永久有效";
						} else {
							var data = parseInt(d[1]);
							var timearr = [parseInt(data/86400), parseInt((data%86400)/3600), parseInt((data%3600)/60)];
							return timearr[0] + "天" + timearr[1] + "时" + timearr[2] + "分"; 
						}
					} else {
						return "永久有效";
					}
               }
			},
            {
				"data": "enable",
				"render": function (d, t, f) {
					if (d == 0) {
						return '<a class="btn btn-danger btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击启用"><i class="icon-remove"></i> 已禁用 </a>';
					} else {
						return '<a class="btn btn-success btn-xs" onclick="set_enable(this)" data-toggle="tooltip" data-container="body" title="点击禁用"><i class="icon-ok"></i> 已启用 </a>';
					}
               }
			},
			{
				"data": null,
				"width": 80,
				"orderable": false,
				"render": function(d, t, f) {
					return '<div class="btn-group btn-group-xs"><a class="btn btn-zx" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
				}
			},
            {
				"data": null,
				"width": 60,
				"orderable": false,
				"searchable": false,
				"defaultContent": '<input type="checkbox" value="1 0" />'
			}
        ],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			$("body > div.tooltip").remove();
			$('[data-toggle="tooltip"]').tooltip();
		}
	});
}

function createInitModal() {
	$("#modal_edit, #modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	dtReloadData(oTabUser, false);
}

function DoSave() {
	if (!verification()) return;

	var data = jsonTraversal(g_user, jsTravGet);
	var remain_t1 = $("#remain_t1").val() ? $("#remain_t1").val() : 0,
		remain_t2 = $("#remain_t2").val() ? $("#remain_t2").val() : 0,
		remain_t3 = $("#remain_t3").val() ? $("#remain_t3").val() : 0,
		macval = $("#maclist").val(),
		bind = $("#bind").is(":checked") ? "mac" : "none";
		num = 0;

	if (data.expire == "1") {
		data.expire = [1, $("#expire_text").val().replace(/\//g, "").replace(/\:/g, "")];
	} else {
		data.expire = [0, $("#expire_text").val().replace(/\//g, "").replace(/\:/g, "")];
	}
	num = parseInt(remain_t1)*86400 + parseInt(remain_t2)*3600 + parseInt(remain_t3)*60;
	if (data.remain == "1") {
		data.remain = [1, num];
	} else {
		data.remain = [0, 0];
	}
	
	if (macval == "") {
		data.maclist = [];
	} else {
		data.maclist = macval.split("\n")
	}
	
	if (bind == "none") {
		data.maclist = [];
	}

	if (data.expire[1] == "") {
		var times = getMyDate();
		data.expire[1] = times + " 000000";
	}

	if (modify_flag == "add") {
		cgicall("UserAdd", data, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("添加失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		})
	} else {
		cgicall("UserSet", data, function(d) {
			var func = {
				"sfunc": function() {
					initData();
				},
				"ffunc": function() {
					createModalTips("修改失败！" + (d.data ? d.data : ""));
				}
			}
			cgicallBack(d, "#modal_edit", func);
		})
	}
}

function edit(that){
	var expire0,
		expire1,
		remain0,
		remain1;

	$("#name").prop("disabled", true);
	modify_flag = "mod";
	getSelected(that);

	jsonTraversal(nodeEdit[0], jsTravSet);
	expire0 = (nodeEdit[0].expire)[0];
	expire1 = (nodeEdit[0].expire)[1];
	remain0 = (nodeEdit[0].remain)[0];
	remain1 = (nodeEdit[0].remain)[1];
	
	if (expire0 == "1") {
		$("#expire").get(0).checked = true;
	} else {
		$("#expire").get(0).checked = false;
	}
	$("#expire_text").val(expire1.substring(0,4) + "/" + expire1.substring(4,6) + "/" + expire1.substring(6,8) + " " + expire1.substring(9,11) + ":" + expire1.substring(11,13) + ":" + expire1.substring(13,15));
	
	if (remain0 == "1") {
		$("#remain").get(0).checked = true;
	} else {
		$("#remain").get(0).checked = false;
	}
	var timearr = [parseInt(parseInt(remain1)/86400), parseInt((parseInt(remain1)%86400)/3600), parseInt((parseInt(remain1)%3600)/60)];
	$("#remain_t1").val(timearr[0]);
	$("#remain_t2").val(timearr[1]);
	$("#remain_t3").val(timearr[2]);
	$("#maclist").val(dtObjToArray(nodeEdit[0].maclist).join("\n"));

	OnBindmac();
	OnExpire();
	OnRemain();
	
	$('#modal_edit').modal("show");
}

function DoDelete() {
	var namearr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		namearr.push(nodeEdit[i].name)
	}
	
	cgicall("UserDel", namearr, function(d) {
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
	});
}

function set_enable(that) {
	getSelected(that)
	
	if (nodeEdit[0].enable == 1) {
		nodeEdit[0].enable = 0;
	} else {
		nodeEdit[0].enable = 1;
	}
	
	cgicall("UserSet", nodeEdit[0], function(d) {
		if (d.status == 0) {
			initData();
		} else {
			createModalTips("修改失败！" + (d.data ? d.data : ""));
		}
	})
}

function initEvents() {
	$(".add").on("click", OnAddUser);
	$(".delete").on("click", function() {OnDelete()});
	$('.checkall').on('click', OnSelectAll);
	$("#bind").on("click", OnBindmac);
	$("#expire").on("click", OnExpire);
	$("#remain").on("click", OnRemain);
	$(".showlock").on("click", OnShowlock);
	
	$('#expire_text').datetimepicker({
		lang: 'ch',
		format: 'Y/m/d H:i:00'
	});
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAddUser() {
	modify_flag = "add";
	$("#name").prop("disabled", false);
	$("#enable").prop("checked", true);
	$(".empty").val("");
	
	$('#expire, #multi, #bind, #remain').prop("checked", false);
	OnBindmac();
	OnExpire();
	OnRemain();
	$('#modal_edit').modal("show");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length == 0) {
		createModalTips("请选择要删除的列表！");
		return;
	}
	
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
}

function OnSelectAll() {
	dtSelectAll(this, oTabUser);
}

function OnBindmac() {
	if ($("#bind").is(":checked")) {
		$("#maclist").prop("disabled", false);
	} else {
		$("#maclist").prop("disabled", true);
	}
}

function OnExpire() {
	if ($("#expire").is(":checked")) {
		$("#expire_text").prop("disabled", false);
	} else {
		$("#expire_text").prop("disabled", true);
	}
}

function OnRemain() {
	if ($("#remain").is(":checked")) {
		$("#remain_t1,#remain_t2,#remain_t3").prop("disabled", false);
	} else {
		$("#remain_t1,#remain_t2,#remain_t3").prop("disabled", true);
	}
}

function OnShowlock(that) {
	var tt = $(this).closest(".form-group").find("input.form-control")
	if (tt.length > 0 && (tt.attr("type") == "text" || tt.attr("type") == "password")) {
		if (tt.attr("type") == "password") {
			$(this).find("i").removeClass("icon-lock").addClass("icon-unlock");
			tt.attr("type", "text");
		} else {
			$(this).find("i").removeClass("icon-unlock").addClass("icon-lock");
			tt.attr("type", "password")
		}
	}
}

function getMyDate() {
	var myDate = new Date();
	var year = myDate.getFullYear();
	var month = myDate.getMonth() + 1;
	var day = myDate.getDate();
	if (month < 10) month = "0" + month;
	if (day < 10) day = "0" + day;

	return year + month + day;
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabUser.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabUser);
	}
}
