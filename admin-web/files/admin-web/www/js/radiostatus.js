var oTabRadio,
	oTabNeighbor,
	oTabWlanstate,
	clearInitData,
	hideColumns = ["6","8"],
	wlanStateID = {};

$(function() {
	oTabRadio = createDtRadios();
	oTabNeighbor = createDtNeighbor();
	oTabWlanstate = createDtWlanstate();
	createInitModal();
	initEvents();
});

function createDtRadios() {
	var firstHideCol = true;
	var cmd = {"key": "RadioList"}
	return $("#table_radios").dataTable({
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
				"data": "prototol"
			},
			{
				"data": "band",
				"render": function(d, t, f) {
					return d.toUpperCase();
				}
			},
			{
				"data": "channel_id"
			},
			{
				"data": "bandwidth"
			},
			{
				"data": "user_num",
				"render": function(d, t, f) {
					return '<a class="underline" href="onlineuser.html?filter='+ f.ap +'">' + d + '</a>';
				}
			},
			{
				"data": "power"
			},
			{
				"data": "channel_use",
				"render": function(d, t, f) {
					return d + '%';
				}
			},
			{
				"data": "noise"
			},
			{
				"data": "ap_describe",
				"render": function(d, t, f) {
					var data = d;
					if (data == "default" || data == "") data = f.ap;
					return '<a class="underline" href="apstatus.html?filter='+ f.ap +'">' + data + '</a><span style="display:none;">' + f.ap + '</span>';
				}
			},
			{
				"data": "wlanstate",
				"render": function(d, t, f) {
					return '<a href="javascript:;" onclick="openWlanstate(\'' + f.band + '\',\'' + f.ap + '\')" data-toggle="tooltip" data-container="body" title="查看"><span class="badge">' + d + '</span></a>';
				}
			},
			{
				"data": "nwlan",
				"render": function(d, t, f) {
					return '<a href="javascript:;" onclick="openNeighbor(\'' + f.band + '\',\'' + f.ap + '\')" data-toggle="tooltip" data-container="body" title="查看"><span class="badge">' + d + '</span></a>';
				}
			}
		],
		"rowCallback": function(nTd, sData, oData, iRow, iCol) {
			dtBindRowSelectEvents(nTd);
			$(nTd).find("td:first").html(iRow + 1);
		},
		"drawCallback": function() {
			//提示
			$("body > div.tooltip").remove();
			$('[data-toggle="tooltip"]').tooltip();
		},
		"preDrawCallback": function() {
			if (firstHideCol) {
				initHideCol();
				firstHideCol = false;
			}
		},
		"initComplete": function() {
			//过滤
			var furl = getRequestFilter();
			if (furl != "") {
				this.fnFilter(furl);
			}
		}
	});
}

function createDtWlanstate() {
	return $('#table_wlanstate').dataTable({
		// "pagingType": "full_numbers",
		"order": [[4, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"columns": [
			{
				"data": "ath"
			},
			{
				"data": "essid"
			},
			{
				"data": "bssid",
				"render": function(d, t, f) {
					if ("bssid" in f) {
						return d;
					} else {
						return "";
					}
				}
			},
			{
				"data": "rate",
				"render": function(d) {
					return d + 'Mb/s';
				}
			},
			{
				"data": "users",
				"render": function(d, t, f){
					return '<a class="underline" href="onlineuser.html?filter=' + wlanStateID.apid + '||' + f.essid + '||' + wlanStateID.band +'">' + d + '</a>';
				}
			}
		]
	});
}

function createDtNeighbor() {
	return $("#table_neighbor").dataTable({
		// "pagingType": "full_numbers",
		"order": [[3, 'asc']],
		"language": {"url": "../../js/black/dataTables.chinese.json"},
		"columns": [
			{
				"data": "ssid"
			},
			{
				"data": "bssid"
			},
			{
				"data": "channel_id"
			},
			{
				"data": "rssi",
				"sWidth": 180,
				"render": function(d, t, f){
					return '<div class="prorssi" value="' + RssiConvert(d) + '"><div class="prorssi-bar" style="width:'+RssiConvert(d)+'%;"></div><div class="prorssi-tip">' + d + 'dBm</div></div>';
				}
			}
		],
		"fnDrawCallback": function() {
			$('.prorssi').each(function(index, element) {
				var val = $(element).attr("value");
				$(element).find('.prorssi-bar').css('background-color', RssiColor(val));
			});
		}
	});
}

function createInitModal() {
	$("#modal_neighbor, #modal_wlanstate, #modal_columns").modal({
		"backdrop": "static",
		"show": false
	});
}

function setTimeInitData() {
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
   	}, 10000);
}

function initData() {
	dtReloadData(oTabRadio, false, function(d) {
		initHideCol();
	});	
}

function initHideCol() {
	cgicall("GetHideColumns", "webui/hidepage/wireless/radiostatus", function(d) {
		var harr = hideColumns;
		if (d.status == 0) {
			if (Object.prototype.toString.call(d.data) === '[object Array]') {
				hideColumns = d.data;
				harr = d.data;
			}
		}
		dtHideColumn(oTabRadio, harr);
		setTimeInitData();
	});
}

function openWlanstate(g, ap) {
	wlanStateID.band = g;
	wlanStateID.apid = ap;
	cgicall('WLANState', wlanStateID, function(d) {
		if (d.status == 0) {
			dtRrawData(oTabWlanstate, dtObjToArray(d.data));
		} else {
			console.log("open wlanstate fail" + (d.data ? d.data : ""));
		}
		$("#modal_wlanstate").modal("show");
	});
}

function openNeighbor(g, ap) {
	var obj = {
		"band": g,
		"apid": ap
	}

	cgicall('NWLAN', obj, function(d) {
		if (d.status == 0) {
			dtRrawData(oTabNeighbor, dtObjToArray(d.data));
		} else {
			console.log("open neighbor fail" + (d.data ? d.data : ""));
		}
		
		$("#modal_neighbor").modal("show");
	});
}

function DoHidecolumns() {
	var obj = {};
	var hidenum = [];
	$('#modal_columns .checkbox input').each(function(index, element) {
		if (!$(element).is(":checked")) {
			hidenum.push(index);
		}
	});
	obj.page = 'webui/hidepage/wireless/radiostatus';
	obj.data = hidenum;
	cgicall('DtHideColumns', obj, function(d) {
		var func = {
			"sfunc": function() {
				hideColumns = hidenum;
				dtHideColumn(oTabRadio, hidenum);
			},
			"ffunc": function() {
				createModalTips("操作失败！" + (d.data ? d.data : ""));
			}
		}
		cgicallBack(d, "#modal_columns", func);
	});
}

function initEvents() {
	$('.hidecol').on('click', OnHidecol);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnHidecol() {
	$("#modal_columns .checkbox input").each(function(index, element) {
		$(element).prop('checked', true);
		for (var i = 0; i < hideColumns.length; i++) {
			if (hideColumns[i] == index) {
				$(element).prop('checked', false);
				break;
			}
		}
	});
	$('#modal_columns').modal("show");
}

function getRequestFilter() {
	var arr,
		restr = "",
		obj = {},
		url = window.location.search;
		
	if (url && url != "") {
		url = url.substring(1);
		arr = url.split("&");
		
		for (var i = 0; i < arr.length; i ++) {
			obj[arr[i].split("=")[0]] = arr[i].split("=")[1];
		}
		
		if ("filter" in obj) {
			restr = obj.filter.split("||").join(" ");
		}
	}
	return decodeURI(restr);
}

function RssiConvert(d) {
	var num = parseInt(d);
	var per = Math.round((100*num + 11000)/75); //-30信号强度为100%,-110为0%
	if (per < 0) per = 0;
	if (per > 100) per = 100;
	return per;
}

function RssiColor(sRate) {
	var r = 0,
		g = 0,
		b = 0,
		rate = parseInt(sRate);

	r = (0 - 220)/100 * rate + 220;
	g = (170 - 220)/100 * rate + 220;
	b = 220;

	return 'rgb(' + parseInt(r) + ', ' + parseInt(g) + ', ' + parseInt(b) + ')';
}
