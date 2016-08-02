var oTabDhcp,
	clearInitData;

$(function() {
	oTabDhcp = createDtDhcp();
});

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
   	}, 5000);
}

function createDtDhcp() {
	var cmd = {"key": "GetDhcpLease"}
	return $("#table_dhcp").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"ajax": {
			"url": "/call/ucicall",
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
				"data": "hostname",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "ipaddr"
			},
			{
				"data": "macaddr"
			},
			{
				"data": "expires",
				"render": function(d) {
					var s = d.replace("d", "天");
					s = s.replace("h", "时");
					s = s.replace("m", "分");
					s = s.replace("s", "秒");
					return s;
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			$(nTd).find("td:first").html(iRow + 1);
		},
		"initComplete": function() {
			setTimeInitData();
		}
	});
}
function initData() {
	dtReloadData(oTabDhcp, false, function(d) {
		setTimeInitData();
	});	
}
