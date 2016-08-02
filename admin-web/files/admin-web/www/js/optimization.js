var dataCon;

$(document).ready(function() {
	initData();
	initEvent();
});

function initData() {
	cgicall('GetOptimization', function(d) {
		if (d.status == 0) {
			dataCon = d.data;
			jsonTraversal(dataCon, jsTravSet);
		} else {
			console.log("GetLoadBalance error " + (d.data ? d.data : ""));
		}
	});
}

function saveSubmit() {
	var obj = jsonTraversal(dataCon, jsTravGet);
	var sobj = {
		"data": obj,
		"oldData": dataCon
	}
	cgicall('SaveOptimization', sobj, function(d) {
		if (d.status == 0) {
			createModalTips('保存成功！');
			initData();
		} else {
			createModalTips('保存失败！');
		}
	});
}

function initEvent() {
	$('.submit').on('click', saveSubmit);
}

