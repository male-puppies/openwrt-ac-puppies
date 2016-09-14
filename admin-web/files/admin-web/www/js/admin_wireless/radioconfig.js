var country = "China",
	radio_cfg = {
			"radio_2g": {
				"proto": "",
				"bandwidth": "",
				"chanid": "",
				"power": "",
				"usrlimit": ""
			},
			"radio_5g": {
				"proto": "",
				"bandwidth": "",
				"chanid": "",
				"power": ""
			},
			"opt": {
				"mult": "",
				"rate": "",
				"inspeed": "",
				"isolation": "",
				"enable": ""
			}
	}
$(function() {
	createInitModal();
	verifyEventsInit();
	initEvents();
	initData();
});

function createInitModal() {
	$("#modal_tips").modal({
		"backdrop": "static",
		"show": false
	});
}

function initData() {
	var obj = {
		"page": 1,
		"count": 10000,
	}
	cgicall.get('radio_get', obj, function(d) {
		if(d.status == 0) {
			country = d.data.country
			setCountryChannel(d.data);
			jsonTraversal(d.data, jsTravSet);
		} else {
			console.log("radio_get error " + (d.data ? d.data : ""));
		}
	});
}

function initEvents() {
	$('.submit').on('click', saveSubmit);
	$('#radio_2g__proto').on('change', function() {
		var op = $(this).find('option:selected').val();
		channel_2gSet(op);
	});
	$('#radio_5g__proto').on('change', function() {
		var op = $(this).find('option:selected').val();
		channel_5gSet(op);
	});
	$("#radio_2g__bandwidth").on('change', function() {
		var op = $(this).find('option:selected').val();
		country_2gSet(op);
	});
	$("#radio_5g__bandwidth").on('change', function() {
		var op = $(this).find('option:selected').val();
		country_5gSet(op);
	});
	$('[data-toggle="tooltip"]').tooltip();
}

function channel_2gSet(obj) {
	var op2,
		proto,
		bol = true,
		pauto = '<option value="auto">auto</option>',
		p20 = '<option value="20">20</option>',
		p40p = '<option value="40+">40+</option>',
		p40m = '<option value="40-">40-</option>',
		band2g = $("#radio_2g__bandwidth");
	if (typeof(obj) == 'object') {
		proto = obj.radio_2g.proto;
		bol = false;
	} else {
		proto = obj;
	}
	switch (proto)
	{
//		条件合并
		case 'b':
		case 'g':
		case 'bg':
			band2g.html(p20);
			break;
		case 'n':
		case 'bng':
		default:
			band2g.html(pauto + p20 + p40p + p40m);
			break;
	}
	if(bol){
		op2 = band2g.find('option:selected').val();
		country_2gSet(op2);
	}
}

function channel_5gSet(obj) {
	var op2,
		proto,
		bol = true,
		pauto = '<option value="auto">auto</option>',
		p20 = '<option value="20">20</option>',
		p40p = '<option value="40+">40+</option>',
		p40m = '<option value="40-">40-</option>',
		band5g=$("#radio_5g__bandwidth");

	if (typeof(obj) == 'object') {
		proto = obj.radio_5g.proto;
		bol = false;
	} else {
		proto = obj;
	}
	switch (proto)
	{
		case 'a':
			band5g.html(p20);
			break;
		case 'n':
		case 'an':
		default:
			band5g.html(pauto + p20 + p40p + p40m);
			break;
	}
	if(bol){
		op2 = band5g.find('option:selected').val();
		country_5gSet(op2);
	}
}

function country_2gSet(obj) {
	var str_2g,
		cband,
		ctc_2g = [];

	if (typeof(obj) == 'object') {
//		number转string
		cband = obj.radio_2g.bandwidth + '';
	} else {
		cband = obj;
	}
	ctc_2g = countryToSetChannel(country, cband, '2g');
	for (var k in ctc_2g) {
		str_2g += '<option>' + ctc_2g[k] + '</option>';
	}
	$("#radio_2g__chanid").html(str_2g);
}

function country_5gSet(obj) {
	var str_5g,
		cband,
		ctc_5g = [];

	if (typeof(obj) == 'object') {
		cband = obj.radio_5g.bandwidth + '';
	} else {
		cband = obj;
	}
	ctc_5g = countryToSetChannel(country, cband, '5g');
	for (var k in ctc_5g) {
		str_5g += '<option>' + ctc_5g[k] + '</option>';
	}
	$("#radio_5g__chanid").html(str_5g);
}

function setCountryChannel(obj) {
	channel_2gSet(obj); //2g 信道带宽option设置
	channel_5gSet(obj);
	country_2gSet(obj); //国家码对应信道
	country_5gSet(obj);
}

function saveSubmit() {
	if(!verification()) return false;
	var obj = jsonTraversal(radio_cfg, jsTravGet);
	cgicall.post('radio_set', obj, function(d) {
		if(d.status == 0) {
			createModalTips('保存成功！');
			initData();
		} else {
			createModalTips('保存失败！');
		}
	});
}
