var oTabUser,
	modify_flag = "add",
	nodeEdit = [],
	gid = 63;
	g_user = {
		enable: 1,
		username: "",
		register: "",
		password: "",
		userdesc: "",
		multi: 1,
		bindmac: [],
		bindip: [],
		expire: ""
	};

$(function(){
	oTabUser = createDtUser();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDtUser() {
	var cgiobj = {
		page: 1,
		count: 10000,
		order: "uid",
		desc: 1
	}
	return $("#table_groupuser").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/lib/dataTables.chinese.json'},
		"ajax": {
			"url": cgiDtUrl("user_get",cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
            {
				"data": "username",
            },
            {
				"data": "userdesc",
				"render": function (d, t, f) {
					if (d == "") {
						return "--"
					} else {
						return d;
					}
               }
            },
			{
				"data": "expire",
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
	var data = jsonTraversal(g_user, jsTravGet),
		mac_chk = $("#mac_chk").is(":checked"),
		ip_chk = $("#ip_chk").is(":checked"),
		expire_chk = $("#expire_chk").is(":checked"),
		macval = $("#bindmac").val(),
		ipval = $("#bindip").val();
	//未勾选过期时间或过期时间为空
	if(!expire_chk){
		data.expire = ""
	}
	if (!mac_chk || macval == "") {
		data.bindmac = [];
	} else {
		data.bindmac = macval.split("\n")
	}
	if (!ip_chk || ipval == "") {
		data.bindip = [];
	} else {
		data.bindip = ipval.split("\n")
	}

	if (modify_flag == "add") {
		data.gid = gid;
		cgicall.post("user_add", data, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		})
	} else {
		data.gid = nodeEdit[0].gid;
		data.uid = nodeEdit[0].uid;
		data.register = nodeEdit[0].register;
		cgicall.post("user_set", data, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("修改失败！" + (d.data ? d.data : ""));
			});
		})
	}
}

function edit(that){
	$("#username").prop("disabled", true);
	modify_flag = "mod";
	getSelected(that);
	jsonTraversal(nodeEdit[0], jsTravSet);
	$("#bindmac").val(dtObjToArray(nodeEdit[0].bindmac).join("\n"));
	$("#bindip").val(dtObjToArray(nodeEdit[0].bindip).join("\n"));
	$("#mac_chk").prop("checked",($("#bindmac").val() != ""))
	$("#ip_chk").prop("checked",($("#bindip").val() != ""))
	$("#expire_chk").prop("checked",($("#expire").val() != ""))
	OnBindmac();
	OnBindip();
	OnExpire();
	$('#modal_edit').modal("show");
}

function DoDelete() {
	var idarr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		idarr.push(nodeEdit[i].uid)
	}
	var cgiobj = {
		uids: idarr
	}
	cgicall.post("user_del", cgiobj, function(d) {
		cgicallBack(d, initData, function() {
				createModalTips("删除失败！" + (d.data ? d.data : ""));
			});
	});
}

function set_enable(that) {
	getSelected(that)

	if (nodeEdit[0].enable == 1) {
		nodeEdit[0].enable = 0;
	} else {
		nodeEdit[0].enable = 1;
	}

	cgicall.post("user_set", nodeEdit[0], function(d) {
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
	$("#mac_chk").on("click", OnBindmac);
	$("#ip_chk").on("click", OnBindip);
	$("#expire_chk").on("click", OnExpire);
	$(".showlock").on("click", OnShowlock);

	$('#expire').datetimepicker({
		lang: 'ch',
		format: 'Y-m-d H:i:00'
	});
	$('[data-toggle="tooltip"]').tooltip();
}

function OnAddUser() {
	modify_flag = "add";
	var cgiobj = {
		page: 1,
		count: 10000
	}
	cgicall.get("acgroup_get",cgiobj,function (d) {
		if(d.status == 0){
			for (var i = d.data.length-1; i >= 0; i--) {
				if(d.data[i].groupname == "default"){
					gid = d.data[i].gid;
					return;
				}
			}
		}
		else{
			console.log("获取gid失败");
		}
	})
	$("#username").prop("disabled", false);
	$("#enable").prop("checked", true);
	$(".empty").val("");
	$('#expire_chk, #multi, #mac_chk, #ip_chk').prop("checked", false);
	OnBindmac();
	OnBindip();
	OnExpire();
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
	if ($("#mac_chk").is(":checked")) {
		$("#bindmac").prop("disabled", false);
	} else {
		$("#bindmac").prop("disabled", true);
	}
}

function OnBindip() {
	if ($("#ip_chk").is(":checked")) {
		$("#bindip").prop("disabled", false);
	} else {
		$("#bindip").prop("disabled", true);
	}
}

function OnExpire() {
	if ($("#expire_chk").is(":checked")) {
		$("#expire").prop("disabled", false);
	} else {
		$("#expire").prop("disabled", true);
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