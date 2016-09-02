var oTabList,
	clearInitData,
	nodeEdit = [];

$(function() {
	oTabList = createDtList();
	createInitModal();
	initEvents();
});

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
	}, 5000);
}

function createDtList() {
	var cgiobj = {
		page: 1,
		count: 10000,
		order: "uid",
		desc: 1
	}
	return $("#table_list").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/lib/dataTables.chinese.json"},
		"ajax": {
			"url": cgiDtUrl("online_get", cgiobj),
			"type": "GET",
			"dataSrc": dtDataCallback,
		},
		"columns": [
			{
				"data": null,
				"width": 60
			},
			{
				"data": "username"
			},
			{
				"data": "type",
				"render": function(d, t, f) {
					switch(d) {
						case "web":
							return "web认证";
							break;
						case "wechat":
							return "微信认证";
							break;
						case "sms":
							return "短信认证";
							break;
						default:
							return "--"
							break;
					}
				}
			},
			{
				"data": "ip"
			},
			{
				"data": "mac"
			},
			{
				"data": null,
				"render": function(d, t, f) {
					return arrive_timer_format(f.active - f.login);
				}
			},
			{
				"data": null,
				"orderable": false,
				"render": function(d, t, f) {
					return '<a class="btn btn-danger btn-xs" onclick="Onoffline(this)"><i class="icon-ban-circle"></i> 强制下线 </a>';
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
		"initComplete": function() {
			setTimeInitData();
		}
	});
}

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	var obj = {};
	// getSelected(); //不要用这个 会覆盖全局
	var nodeEdit = dtGetSelected(oTabList);
	for (var i = 0; i < nodeEdit.length; i++) {
		obj[nodeEdit[i].mac] = "1";
	}

	dtReloadData(oTabList, false, function(d) {
		var rows = oTabList.api().rows(),
			data = rows.data(),
			nodes = rows.nodes();

		for (var j = 0; j < nodes.length; j++) {
			var mac = data[j].mac;
			if (mac in obj) {
				$(nodes[j]).addClass("row_selected").find('td input[type="checkbox"]').prop('checked', true);
			}
		}

		setTimeInitData();
	});
}

function Doffline() {
	var arr = [];
	for (var i = 0; i < nodeEdit.length; i++) {
		arr.push(nodeEdit[i].ukey);
	}
	var cgiobj = {
		ukeys: arr
	}
	cgicall.post("online_del", cgiobj, function(d) {
		cgicallBack(d, initData, function(){
			createModalTips("强制下线失败！" + (d.data ? d.data : ""));
		});
	});
}

function initEvents() {
	$(".checkall").on("click", OnSelectAll);
	$(".offline").on("click", function(d) {Onoffline()})
	$('[data-toggle="tooltip"]').tooltip();
}

function OnSelectAll() {
	dtSelectAll(this, oTabList);
}

function Onoffline(that) {
	getSelected(that);
	if (nodeEdit.length < 1) {
		createModalTips("请选择要强制下线的用户！");
		return;
	}
	createModalTips("是否确认使该用户强制下线？", "Doffline");
}

function getSelected(that) {
	nodeEdit = [];
	if (that) {
		var node = $(that).closest("tr");
		var data = oTabList.api().row(node).data();
		nodeEdit.push(data);
	} else {
		nodeEdit = dtGetSelected(oTabList);
	}
}

function arrive_timer_format(s) {
	var t,
		s = parseInt(s);
	if (s > -1) {
		hour = Math.floor(s / 3600);
		min = Math.floor(s / 60) % 60;
		sec = s % 60;
		day = parseInt(hour / 24);
		if (day > 0) {
			hour = hour - 24 * day;
			t = day + "天 " + hour + "时 ";
		} else {
			t = hour + "时 ";
		}
		t += min + "分 " + sec + "秒";
	}
	return t;
}
