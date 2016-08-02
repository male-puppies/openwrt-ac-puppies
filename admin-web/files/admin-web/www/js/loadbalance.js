var dataCon;

$(function() {
	initData();
	verifyEventsInit();
	initEvents();
});

function initData() {
	cgicall("GetLoadBalance", function(d) {
		if (d.status == 0) {
			dataCon = d.data;
			jsonTraversal(dataCon, jsTravSet);
			OnDisabledChanged(dataCon.sta_enable);
		} else {
			console.log("GetLoadBalance error " + (d.data ? d.data : ""));
		}
	});
}

function saveSubmit() {
	if (!verification()) return;

	var obj = jsonTraversal(dataCon, jsTravGet);
	var sobj = {
		"data": obj,
		"oldData": dataCon
	}
	cgicall('SaveLoadBalance', sobj, function(d) {
		if (d.status == 0) {
			createModalTips('保存成功！');
			initData();
		} else {
			createModalTips('保存失败！');
		}			
	});
}

function initEvents() {
	$("#sta_enable").on("click", function() {
		OnDisabledChanged($(this).is(":checked") ? "1" : "0");
	});
	$(".submit").on("click", saveSubmit);
	$('[data-toggle="tooltip"]').tooltip();
}

function OnDisabledChanged(v) {
	if (v == "1") {
		$("#rssi_limit, #flow_limit, #sensitivity").prop("disabled", false);
	} else {
		
		$("#rssi_limit, #flow_limit, #sensitivity").prop("disabled", true);
	}
}
