var mark1,
	mark2,
	cpu_stat = {},
	clearInitData;


var f1 = {
		"recv": [
			{
				"name":"wan0",
				"data": [1, 2, 3, 4]
			},{
				"name":"wan1",
				"data": [5, 6, 7, 8]
			},{
				"name":"wan2",
				"data": [9, 10, 11, 12]
			}
		],
		"xmit": [
			{
				"name":"wan0",
				"data": [13, 14, 15, 16]
			},{
				"name":"wan1",
				"data": [17, 18, 19, 20]
			},{
				"name":"wan2",
				"data": [21, 22, 23, 24]
			}
		]
	}


$(function() {
	$(".title i.spin-load").css("display", "inline-block");
	initEvents();
	initData();
});

function setTimeInitData() {
	if (mark1 == false || mark2 == false) {return}
	clearTimeout(clearInitData);
	clearInitData = setTimeout(function(){
		initData();
	}, 5000);
}

function initData() {
	mark1 = false;
	mark2 = false;

	containerEth();
	containerUser();

	cgicall.get("GetStatus", function(d) {
		if (d.status == 0) {
			setSystem(d.data);
			mark1 = true;
			setTimeInitData();
		} else {
			console.log("获取数据失败！请尝试重新加载！" + (d.data ? d.data : ""));
		}
	});

	cgicall.get("GetEthStatus", function(d) {
		if (d.status == 0) {
			setInterface(d.data);
			mark2 = true;
			setTimeInitData();
		} else {
			console.log("获取数据失败！请尝试重新加载！" + (d.data ? d.data : ""))
		}
	});
}

function containerEth() {
	var data = ObjClone(f1);
	var arr = [];
	for (var i = 0, ien = data.recv.length; i < ien; i++) {
		if (typeof data.recv[i].name != "undefined") {
			data.recv[i].name = data.recv[i].name + "上行";
		}
		if (typeof data.xmit[i].name != "undefined") {
			data.xmit[i].name = data.xmit[i].name + "下行";
		}
		arr.push(data.recv[i]);
		arr.push(data.xmit[i]);
	}
	$('#container_eth').highcharts({
		chart: {
			type: 'spline',
			zoomType:'x'
		},
		colors: ['#7cb5ec', '#f7a35c'],
		title: {
			text: '网口实时流量',
			x: -20
		},
		subtitle: {
			text: 'xxxxx',
			x: -20
		},
		credits: {
			enabled: 0,
		},
		xAxis: {
			type: 'linear',
			allowDecimals: false,
			tickmarkPlacement: 'on',
			title: {
				text: '（时间）',
				align: 'high'
			},
			labels: {
				formatter: function() {
					return this.value + 5;
				}
			},
			tickInterval: 1
		},
		yAxis: {
			allowDecimals: false,
			min: 0,
			title: {
				text: '︵<br>流<br>量<br>︶',
				align: 'high',
				rotation: 0,
				style: {
					'lineHeight': '14px'
				}
			},
		},
		tooltip: {
			formatter: function() {
				return '[<b>' + (parseInt(this.x) + 1) + '</b>] - [<b>' + this.y + '</b>]';
			}
		},
		legend: {
			layout: 'vertical',
			align: 'right',
			verticalAlign: 'middle',
			borderWidth: 0
		},
		plotOptions: {
			series: {
				// showCheckbox: true
			},
            line:{
                events :{
                    checkboxClick: function(event) {
                        if(event.checked==true) {
                            this.show();
                        }
                        else {
                            this.hide();
                        }
                    },
                    legendItemClick:function(event) {//return false 即可禁用LegendIteml，防止通过点击item显示隐藏系列
                        return false;
                    }
                }
            }
		},
		series: arr
	});
}

function containerUser() {
	var data = ObjClone(f1);
	var arr = [];
	for (var i = 0, ien = data.recv.length; i < ien; i++) {
		if (typeof data.recv[i].name != "undefined") {
			data.recv[i].name = data.recv[i].name + "上行";
		}
		if (typeof data.xmit[i].name != "undefined") {
			data.xmit[i].name = data.xmit[i].name + "下行";
		}
		arr.push(data.recv[i]);
		arr.push(data.xmit[i]);
	}
	$('#container_user').highcharts({
		chart: {
			type: 'spline',
			zoomType:'x'
		},
		colors: ['#7cb5ec', '#f7a35c'],
		title: {
			text: '前十用户实时流量',
			x: -20
		},
		subtitle: {
			text: 'xxxxx',
			x: -20
		},
		credits: {
			enabled: 0,
		},
		xAxis: {
			type: 'linear',
			allowDecimals: false,
			tickmarkPlacement: 'on',
			title: {
				text: '（时间）',
				align: 'high'
			},
			labels: {
				formatter: function() {
					return xtimes(this.value);
				}
			},
			tickInterval: 1
		},
		yAxis: {
			allowDecimals: false,
			min: 0,
			title: {
				text: '︵<br>流<br>量<br>︶',
				align: 'high',
				rotation: 0,
				style: {
					'lineHeight': '14px'
				}
			},
		},
		tooltip: {
			formatter: function() {
				return '[<b>' + (parseInt(this.x) + 1) + '</b>] - [<b>' + this.y + '</b>]';
			}
		},
		legend: {
			layout: 'vertical',
			align: 'right',
			verticalAlign: 'middle',
			borderWidth: 0
		},
		plotOptions: {
			series: {
				// showCheckbox: true
			},
            line:{
                events :{
                    checkboxClick: function(event) {
                        if(event.checked==true) {
                            this.show();
                        }
                        else {
                            this.hide();
                        }
                    },
                    legendItemClick:function(event) {//return false 即可禁用LegendIteml，防止通过点击item显示隐藏系列
                        return false;
                    }
                }
            }
		},
		series: arr
	});
}

function setSystem(d) {
	var cpu = 0,
		memory = parseInt(d.memorycount) * 100 / parseInt(d.memorymax),
		conncount = parseInt(d.conncount) * 100 / parseInt(d.connmax),
		cpu_stat = d.cpu_stat;

	$("#distribution").html(d.distribution);
	$("#version").html(d.version);
	$("#times").html(d.times);
	$("#uptime").html(arrive_timer_format(d.uptime));
	$("#usercount").html(d.usercount);


	$("#cpuidle").data('radialIndicator').animate(cpu);
	$(".cpuidle").html(cpu + " / " + "100");
	$("#memory").data('radialIndicator').animate(memory);
	$(".memory").html(d.memorycount + " KB / " + d.memorymax + " KB");
	$("#conncount").data('radialIndicator').animate(conncount);
	$(".conncount").html(d.conncount + " / " + d.connmax);

	$(".title i.spin-load1").css("display", "none");
}

function setInterface(d) {
	for (var i in d) {
		for (var k in d[i]) {
			if (typeof d[i][k] != "object") {
				if (d[i]["link"] == false) {
					$("." + i + " .zone-big").css("background-position", "0 0");
				} else {
					$("." + i + " .zone-big").css("background-position", "0 -39px");
				}

				if (k == "uptime") {
					$("." + i + " ." + k + " span").html(arrive_timer_format(d[i][k]));
				} else if (k == "speed") {
					if (d[i]["link"] == true) {
						$("." + i + " span." + k).html(d[i][k] + "Mbps");
					}
				} else if (k == "duplex") {
					if (d[i]["link"] == true) {
						var dup = " 全双工";
						if (d[i][k] == "false") {
							dup = " 半双工";
						}
						$("." + i + " span." + k).html(dup);
					}
				} else {
					$("." + i + " ." + k + " span").html(d[i][k]);
				}
			} else {
				if (d[i][k].length == 1) {
					$("." + i + " .dns1 span").html(d[i][k][0]);
				} else if (d[i][k].length == 2) {
					$("." + i + " .dns1 span").html(d[i][k][0]);
					$("." + i + " .dns2 span").html(d[i][k][1]);
				}
			}
		}
	}

	$(".title i.spin-load2").css("display", "none");
}

function initEvents() {
	$('#cpuidle').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#6dd0ef',
		barColor: '#fff'
	});
	$('#memory').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#fad774',
		barColor: '#fff'
	});
	$('#conncount').radialIndicator({
		radius: 24,
		barWidth: 3,
		initValue: 0,
		roundCorner : true,
		percentage: true,
		barBgColor: '#f4866d',
		barColor: '#fff'
	});
}

function arrive_timer_format(s) {
	var t,
		s = parseInt(s);
	if (s > -1) {
		var hour = Math.floor(s / 3600),
			min = Math.floor(s / 60) % 60,
			sec = s % 60,
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

function xtimes(num) {
	var s = (60 - parseInt(num)) * 5;
	return arrive_timer_format(s);
}
