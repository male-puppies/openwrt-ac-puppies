
var strRdEnable = "<span class='icon-ok ' title='点击禁用'><span class='icon'></span><span class='opera_state'>已启用</span></span>";
var strRdDisable = "<span class='icon-no' title='点击启用'><span class='icon'></span><span class='opera_state'>已禁用</span></span>";
var strRdIscustom = "<span class='icon-cancel pointer' title='Delete'>&nbsp;&nbsp;&nbsp;&nbsp;</span>"; 
var strRdNocustom = "<span class='icon-cancel-disabled' title='Unable to delete inherent library'>&nbsp;&nbsp;&nbsp;&nbsp;</span>"; 
var strEnaleDel = "<span class='icon-cancel pointer' title='删除该免审对象'>&nbsp;&nbsp;&nbsp;&nbsp;</span>"; 
var strDisableDel = "<span class='icon-cancel-disabled' title='无法删除免审QQ组'>&nbsp;&nbsp;&nbsp;&nbsp;</span>"; 

function renderIpAddr(addr){
	var len = addr.length,str = "";
	for(var k = 0; k<len; k++){
		if(addr[k].Ip != "" && addr[k].Mask != ""){
			str += '<div class="ipaddr">' + addr[k].Ip + "/" + addr[k].Mask + "</div>";
		}
	}
	return str;
}

function renderEnable(en) {
	return en == true ?  '已启用':  '已禁用';
}

function renderOperations(id, ops) {
	var strHtml ='';
	for (var i = 0; i < ops.length ; i++) {
		strHtml += "&nbsp;&nbsp;"
		switch(ops[i].type){
			case "update":
				strHtml += '<a class="pointer updata" onclick="'+ 
				(typeof(ops[i].func) == 'string' ? 
					ops[i].func : 'set_update') + '(\''+ id +'\')">Update</a>';
			break;
			case "edit":
				//if(id == "all_users"){id = "All User/Group"}
				strHtml += '<a class="opera_style fontwidth_family" title="编辑" onclick="'+
				 (typeof(ops[i].func) == 'string' ? 
				 	ops[i].func : 'set_edit') + '(\''+ id +'\')">'+(ops[i].val ? ops[i].val : id)+'</a>';
			break;
			case "getMessage":
				strHtml += '<a class="opera_style" title="Edit" onclick="' + (typeof(ops[i].func) == 'string' ? ops[i].func : 'getNameMessage') +'(\''+ id +'\', \''+ ops[i].iscustom + '\', \'' + ops[i].id + '\', \'' + ops[i].des + '\')">'+id+'</a>';		    
			break;
			case "up":
				strHtml += '<a class="pointer icon-rowup" title="Up" onclick="'+
				 (typeof(ops[i].func) == 'string' ? 
				 	ops[i].func : 'set_up') +'(\''+ id +'\')">&nbsp;&nbsp;&nbsp;&nbsp;</a>';
			break;
			case "down":
				strHtml += '<a class="pointer icon-rowdown" title="Down" onclick="'+ 
				(typeof(ops[i].func) == 'string' ? 
					ops[i].func : 'set_down') +'(\''+ id +'\')">&nbsp;&nbsp;&nbsp;&nbsp;</a>';
			break;
			case "check":
				strHtml += '<a title="Check" class="pointer check '+ (ops[i].val ? "":"icon-search") + '" onclick="' + 
				(typeof(ops[i].func) == 'string' ? ops[i].func : 'set_check') +'(\''+ id +'\')">' + 
				 (typeof(ops[i].val) == 'string' ? ops[i].val : '&nbsp;&nbsp;&nbsp;&nbsp;') + '</a>';
			break;
			case "copy":
				strHtml += '<a class="opera_style" title="Copy" onclick="' + 
				(typeof(ops[i].func) == 'string' ? ops[i].func : 'set_copy') +'(\''+ id +'\')">Copy</a>';		    
			break;
			case "delcustom":
					var flag = (ops[i].iscustom == true ? strRdIscustom : strRdNocustom);
				    strHtml += '<a class="" onclick="'+
				    (typeof(ops[i].func) == 'string' ? ops[i].func : 'set_del') +
				    '(\''+ id +'\', \'' + ops[i].iscustom +'\')">'+flag+'</a>';
			break;
			case "delDismissObj":
					var flag1 = (ops[i].iscustom == 3 ? strDisableDel : strEnaleDel);
				    strHtml += '<a class="" onclick="'+
				    (typeof(ops[i].func) == 'string' ? ops[i].func : 'set_del') +
				    '(\''+ id +'\', \'' + ops[i].iscustom +'\')">'+flag1+'</a>';
			break;
			case "del":
				strHtml += '<a class="pointer icon-cancel" title="Delete Object" onclick="' + 
				(typeof(ops[i].func) == 'string' ? ops[i].func : 'set_del') +
				'(\''+ id +'\')"><span class="icon" style="margin-left:20px;"></span></a>';
			break;
			case "enable":
				var en = (ops[i].val == true ? strRdEnable : strRdDisable);
				strHtml += '<a class="pointer" onclick="'+ 
				(typeof(ops[i].func) == 'string' ? ops[i].func : 'set_enable') +
				'(\''+ id + '\', \''+ ops[i].val +'\')">'+ en +'</a>';
			break;
			default:
			break;
		}
	};
	return strHtml;
}

/*
* sZone: 区域,wan / lan
* sId: Html标签的Id
*/
function renderRuntimeZoneList(sZone, sId) {
	//获取zone口地址
	cgicall('Net.GetRuntimePorts("'+ sZone +'")', function(d) {
		for (var i = 0; i < d.length; i++) {
			var strHtml = '<option value='+ d[i].LogicName + '>';
			strHtml += d[i].LogicName + '-' + d[i].Addrs[0].Ip +'</option>';
			$('#' + sId).append($(strHtml));
		};
	});
}
/*
function RssiConvert(d) {
	var rssi = parseInt(d) + 110;
	return parseInt(rssi * 100 / 110);
}
*/
function RssiConvert(d) {
	var num = parseInt(d);
	var per = Math.round((100*num + 11000)/75); //-30信号强度为100%,-110为0%
	if (per < 0) per = 0;
	if (per > 100) per = 100;
	return per;
}

function RssiColor(sRate)
{
	var rate = parseInt(sRate);
	var r = 0, g = 0, b = 0;

	//if (rate < 40) {
		b = (100-rate) * 155 / 100 + 100;
	//}
	//if (rate < 65){
		r = (100-rate) * 155 / 100 + 100;
	//}
	g = rate * 100 / 100 + 200;

	return 'rgb('+parseInt(r)+', '+ parseInt(g) +', ' + parseInt(b) +')';
}