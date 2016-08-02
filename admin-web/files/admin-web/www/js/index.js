var mark1,
	mark2,
	cpu_stat = {},
	clearInitData;

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

	ucicall("GetStatus", function(d) {
		if (d.status == 0) {
			setSystem(d.data);
			mark1 = true;
			setTimeInitData();
		} else {
			console.log("获取数据失败！请尝试重新加载！" + (d.data ? d.data : ""));
		}
	});
	
	ucicall("GetEthStatus", function(d) {
		if (d.status == 0) {
			setInterface(d.data);
			mark2 = true;
			setTimeInitData();
		} else {
			console.log("获取数据失败！请尝试重新加载！" + (d.data ? d.data : ""))
		}
	});
}

function setSystem(d) {
	var mark = false,
		cpu = 0,
		memory = parseInt(d.memorycount) * 100 / parseInt(d.memorymax),
		conncount = parseInt(d.conncount) * 100 / parseInt(d.connmax),
		loadavg = Math.round(d.loadavg[0] /65535 * 100)/100 + ", " + Math.round(d.loadavg[1] /65535 * 100)/100 + ", " + Math.round(d.loadavg[2] /65535 * 100)/100;

	if (typeof d.cpu_stat != "undefined" && typeof d.cpu_stat.iowait != "undefined" && typeof d.cpu_stat.idle != "undefined" && typeof d.cpu_stat.user != "undefined" && typeof d.cpu_stat.irq != "undefined" && typeof d.cpu_stat.softirq != "undefined" && typeof d.cpu_stat.system != "undefined" && typeof d.cpu_stat.nice != "undefined") {
		mark = true;
	}
	if (typeof cpu_stat.idle != "undefined") {
		if (mark) {
			var iowait = parseInt(d.cpu_stat.iowait) - parseInt(cpu_stat.iowait),
				idle = parseInt(d.cpu_stat.idle) - parseInt(cpu_stat.idle),
				user = parseInt(d.cpu_stat.user) - parseInt(cpu_stat.user),
				irq = parseInt(d.cpu_stat.irq) - parseInt(cpu_stat.irq),
				softirq = parseInt(d.cpu_stat.softirq) - parseInt(cpu_stat.softirq),
				system = parseInt(d.cpu_stat.system) - parseInt(cpu_stat.system),
				nice = parseInt(d.cpu_stat.nice) - parseInt(cpu_stat.nice);

			cpu = parseInt((iowait + user + irq + softirq + system + nice) / (iowait + user + irq + softirq + system + nice + idle) * 100);
			$(".cpu-mark").hide();
		}
	}
	
	if (mark) cpu_stat = d.cpu_stat;

	$("#distribution").html(d.distribution);
	$("#version").html(d.version);
	$("#times").html(d.times);
	$("#uptime").html(arrive_timer_format(d.uptime));
	$("#loadavg").html(loadavg);
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



