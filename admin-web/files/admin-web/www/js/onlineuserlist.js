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
	var cmd = {"key": "OnlineGet"}
	return $("#table_list").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
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
					console.log("dataTables POST error...");
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
				"data": "name"
			},
			{
				"data": "ip"
			},
			{
				"data": "mac"
			},
			{
				"data": "elapse",
				"render": function(d, t, f) {
					return arrive_timer_format(d);
				}
			},
			{
				"data": "mac",
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
		arr.push(nodeEdit[i].mac);
	}
	cgicall("OnlineDel", arr, function(d) {
		var func = {
			"sfunc": function() {
				initData();
			},
			"ffunc": function() {
				createModalTips("操作失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_tips", func);
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
	createModalTips("该操作会使web认证用户强制下线，自动认证用户不受影响。</br>是否确认强制下线？", "Doffline");
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
