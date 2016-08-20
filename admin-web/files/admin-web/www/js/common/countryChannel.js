function countryToSetChannel(country, channel, radio) {
	var chanar = [];
	if (typeof(country) == 'undefined' || typeof(channel) == 'undefined' || typeof(radio) == 'undefined') return;
	channel = channel.toLowerCase();
	
	switch (country)
	{
		case 'China':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'US':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','132','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','136','153','161'];
						return chanar;
						break;
				}
			}
			break;
		case 'Japan':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13','14'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','132'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','136'];
						return chanar;
						break;	
				}
			}
			break;
		case 'SouthKorea':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','149','153','157','161'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'Malaysia':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'India':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'Thailand':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','132','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','136','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'Vietnam':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','132','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','136','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		case 'Indonesia':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			}
			break;
		case 'UnitedKingdom':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136','140'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','100','104','108','112','116','120','124','128','132','136'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','100','108','116','124','132'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','104','112','120','128','136'];
						return chanar;
						break;	
				}
			}
			break;
		case 'Singapore':
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','36','40','44','48','52','56','60','64','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['36','44','52','60','149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['40','48','56','64','153','161'];
						return chanar;
						break;	
				}
			}
			break;
		default: //default China
			if (radio === '2g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11','12','13'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','1','2','3','4','5','6','7','8','9','10','11'];
						return chanar;
						break;
					case '40+':
						chanar = ['1','2','3','4','5','6','7'];
						return chanar;
						break;
					case '40-':
						chanar = ['5','6','7','8','9','10','11'];
						return chanar;
						break;	
				}
			} else if (radio === '5g') {
				switch (channel)
				{
					case '20':
						chanar = ['auto','149','153','157','161','165'];
						return chanar;
						break;
					case 'auto':
						chanar = ['auto','149','153','157','161'];
						return chanar;
						break;
					case '40+':
						chanar = ['149','157'];
						return chanar;
						break;
					case '40-':
						chanar = ['153','161'];
						return chanar;
						break;	
				}
			}
			break;
	}
}