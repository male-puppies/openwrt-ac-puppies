var oTab,
	modify_flag = "add",
	nodeEdit = [];

$(function() {
	oTab = createDt();
	createInitModal();
	verifyEventsInit();
	initEvents();
});

function createDt() {
	var cgiobj = {
		"page": 1,
		"count": 10000,
		"order": "tmgrpname",
		"desc": 1,
		"search": "tmgrpname",
		"link": "all"
	}
	return $('#table_timegroup').dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": '../../js/lib/dataTables.chinese.json'},
		"ajax": {
			"url": cgiDtUrl("timegroup_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback
		},
		"columns": [
			{
				"data": null,
				"width": 60,
			},
			{
				"data": "tmgrpname",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "tmgrpdesc",
				"render": function(d, t, f) {
					if (d.length == 0) {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "days",
				"render": function(d, t, f) {
					var str = "";
					if (d.mon == 1) str += ",一";
					if (d.tues == 1) str += ",二";
					if (d.wed == 1) str += ",三";
					if (d.thur == 1) str += ",四";
					if (d.fri == 1) str += ",五";
					if (d.sat == 1) str += ",六";
					if (d.sun == 1) str += ",日";
					
					if (str.length == 0) {
						return "--";
					} else if (str == ",一,二,三,四,五,六,日") {
						return "每天";
					}else {
						return "星期" + str.substring(1);
					}
				}
			},
			{
				"data": "tmlist",
				"render": function(d, t, f) {
					var str = "",
						data = dtObjToArray(d);

					for (var i = 0, ien = data.length; i < ien; i++) {
						str += "，" + consTimes(data[i]);
					}

					if (str.length == 0) {
						return "--";
					} else {
						return str.substring(1);
					}
				}
			},
			{
				"data": "tmgid",
				"width": 90,
				"orderable": false,
				"render": function(d, t, f) {
					if (d == 255) {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-primary disabled" onclick="" data-toggle="tooltip" data-container="body" title="禁止编辑默认组"><i class="icon-pencil"></i></a><a class="btn btn-danger disabled" onclick="" data-toggle="tooltip" data-container="body" title="禁止删除默认组"><i class="icon-trash"></i></a></div>';
					} else {
						return '<div class="btn-group btn-group-xs"><a class="btn btn-primary" onclick="edit(this)" data-toggle="tooltip" data-container="body" title="编辑"><i class="icon-pencil"></i></a><a class="btn btn-danger" onclick="OnDelete(this)" data-toggle="tooltip" data-container="body" title="删除"><i class="icon-trash"></i></a></div>';
					}
				}
			},
			{
				"data": "tmgid",
				"width": 60,
				"orderable": false,
				"searchable": false,
				"render": function(d, t, f) {
					console.log(d)
					if (d == 255) {
						return '<input type="checkbox" value="1 0" disabled />';
					} else {
						return '<input type="checkbox" value="1 0" />';
					}
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
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

function consTimes(obj) {
	var hour_start = parseInt(obj.hour_start) || 0,
		hour_end = parseInt(obj.hour_end) || 0,
		min_start = parseInt(obj.min_start) || 0,
		min_end = parseInt(obj.min_end) || 0;
		
	if (hour_start < 10) hour_start = "0" + hour_start;
	if (hour_end < 10) hour_end = "0" + hour_end;
	if (min_start < 10) min_start = "0" + min_start;
	if (min_end < 10) min_end = "0" + min_end;
	
	return hour_start + ":" + min_start + "-" + hour_end + ":" + min_end;
}

function initData() {
	dtReloadData(oTab, false)
}

function edit(that) {
	$(".form-group.tmadd").remove();
	modify_flag = "mod";
	getSelected(that);
	var obj = ObjClone(nodeEdit[0]);
	
	jsonTraversal(obj, jsTravSet);
	$("#days input").each(function(index, element) {
		if (obj["days"][$(element).val()] == 1) {
			$(element).prop("checked", true).closest("label").addClass("active");
		} else {
			$(element).prop("checked", false).closest("label").removeClass("active");
		}
	});

	var tmlist = dtObjToArray(obj.tmlist);
	for (var i = 0, ien = tmlist.length; i < ien; i++) {
		var tm_arr = consTimes(tmlist[i]).split("-");
		if (i == 0) {
			$(".tmlist.tm .time_star").val(tm_arr[0]);
			$(".tmlist.tm .time_end").val(tm_arr[1]);
		} else {
			OnAddTmlist(tm_arr[0], tm_arr[1]);
		}
	}
	
	$('#modal_edit').modal("show");
}

function DoSave() {
	if(!verification()) return;
	var days_obj = {};
	$("#days input").each(function(index, element) {
		var key = $(element).val();
		if ($(element).closest("label").hasClass("active")) {
			days_obj[key] = 1;
		} else {
			days_obj[key] = 0;
		}
	});

	var tm_arr = [];
	$(".tmlist").each(function(index, element) {
		var tm_obj = {},
			star = $(element).find(".time_star").val(),
			end = $(element).find(".time_end").val();

		star_arr = star.split(":");
		end_arr = end.split(":");
		tm_obj.hour_start = parseInt(star_arr[0]) || 0;
		tm_obj.min_start = parseInt(star_arr[1]) || 0;
		tm_obj.hour_end = parseInt(end_arr[0]) || 0;
		tm_obj.min_end = parseInt(end_arr[1]) || 0;
		tm_arr.push(tm_obj);
	});

	var tmInfo={
        "tmgrpdesc": "",
        "tmgrpname": ""
	}
	var obj = jsonTraversal(tmInfo, jsTravGet);
	obj.days = days_obj;
	obj.tmlist = tm_arr;

	if (modify_flag == "add") {
		cgicall.post("timegroup_add", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("添加失败！" + (d.data ? d.data : ""));
			});
		});
	} else {
		obj.tmgid = nodeEdit[0].tmgid;
		cgicall.post("timegroup_set", obj, function(d) {
			cgicallBack(d, initData, function() {
				createModalTips("修改失败！" + (d.data ? d.data : ""));
			});
		});
	}
}

function DoDelete(){
	var idarr = [];
	for (var i = 0, ien = nodeEdit.length; i < ien; i++) {
		idarr.push(nodeEdit[i].tmgid);
	}
	cgicall.post("timegroup_del", {"tmgids": idarr}, function(d) {
		cgicallBack(d, initData, function() {
			createModalTips("删除失败！" + (d.data ? d.data : ""));
		});
	});
}

function initEvents() {
	$(".add").on("click", OnAdd);
	$('.delete').on('click', function() {OnDelete()});
	$(".checkall").on("click", OnSelectAll);
	$('[data-toggle="tooltip"]').tooltip();
	initTimepicker();
}

function initTimepicker(doc) {
	if (!doc) doc = "body";
	$(".time_star, .time_end", doc).datetimepicker({
		format: 'hh:ii',
		startView: 1,
		minView: 0,
		maxView: 1,
		forceParse: 1,
		autoclose: 1,
		minuteStep: 1
	})
}

function OnAdd() {
	$(".form-group.tmadd").remove();
	modify_flag = "add";
	$('#modal_edit').modal("show");
}

function OnDelete(that) {
	getSelected(that);
	if (nodeEdit.length == 0) {
		createModalTips("请选择要删除的列表！");
		return;
	}
	createModalTips("删除后不可恢复。</br>确定要删除？", "DoDelete");
	$('#modal_tips').modal("show");
}

function OnSelectAll() {
	dtSelectAll(this, $("#table_timegroup"));
}

function OnAddTmlist(s, e) {
	var star = s || "00:00",
		end = e || "23:59",
		node = $("<div>", {
				"class": "form-group tmlist tmadd",
			})
			.append($("<label>", {
					"class": "col-xs-3 control-label",
					"style": "visibility:hidden"
				})
				.html("生效时间段")
			)
			.append($("<div>", {
					"class": "col-xs-6"
				})
				.append($("<input/>", {
						"type": "text",
						"class": "form-control time_star",
						"value": star,
						"readonly": "readonly"
					})
				)
				.append($("<span>")
					.html(" -- ")
				)
				.append($("<input/>", {
						"type": "text",
						"class": "form-control time_end",
						"value": end,
						"verify": "time_group",
						"readonly": "readonly"
					})
				)
			)
			.append($("<div>", {
					"class": "col-xs-3 tip-icons tip-hand"
				})
				.append($("<span>", {
						"class": "icon-tip",
						"data-toggle": "tooltip",
						"data-placement": "bottom",
						"title": "",
						"data-original-title": "删除生效时间段"
					})
					.append($("<i>", {
							"class": "icon-minus-sign",
							"onclick": "OnDelTmlist(this)"
						})
					)
				)
			);

	$(".modal-body fieldset").append(node);
	initTimepicker(node);
	verifyEventsInit(node);
	$('[data-toggle="tooltip"]', node).tooltip();
}

function OnDelTmlist(that) {
	$(that).closest(".form-group").remove();
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTab.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTab);
	}
}