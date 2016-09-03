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
	var cgiobj = {
		keys: encodeURI('["lease"]')
	};
	return $("#table_dhcp").dataTable({
		"pagingType": "full_numbers",
		"order": [[1, 'asc']],
		"language": {"url": "../../js/lib/dataTables.chinese.json"},
		"ajax": {
			"url": cgiDtUrl("system_get", cgiobj),
			"type": "GET",
			"dataSrc": function(d) {
				var data = initBackDatas(d);
				if (data.status == 0 && typeof data.data.lease != "undefined") {
					return dtObjToArray(data.data.lease);
				} else if (data.data.indexOf("loginout") > -1) {
					window.location.href = "/view/admin_login/tologin.html";
				}
				return [];
			},
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
				"data": "ipaddr",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "macaddr",
				"render": function(d, t, f) {
					if (typeof d == "undefined" || d == "") {
						return "--";
					} else {
						return d;
					}
				}
			},
			{
				"data": "expires",
				"render": function(d) {
					return arrive_timer_format(d);
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
