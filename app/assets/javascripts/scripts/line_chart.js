function get_deadlines(data){
	deadlines = []
	for(i = 0; i< data["date"].length; i++){
		if(data["translation_estimate_deadline"][i])
			deadlines = deadlines.concat({
				value: i,
				width: 2,
				color: 'red',
				zIndex: 10,
				dashStyle: 'dot',
				label: "Deadline"
			})
	}
	return deadlines;
}

function line_chart(placeholder,title,data){
	chart_type = 'line'
	var chart_values = chart_defaults(title, data, data["date"], placeholder, chart_type)
	chart_values['tooltip'] = { crosshairs: true }

	series = [{
		name: 'Words sent to translate',
		data: data["words_to_translate"],
		stack: 'translate',
		color: '#4572a7'
	},{
		name: 'Estimate translated words',
    dashStyle: 'dash',
		data: data["translation_estimate"],
		stack: 'translate',
		color: '#0000FF'
/*	},{
		name: 'Words sent to review',
		data: data["words_to_review"],
		stack: 'review',
		color: '#00FF00'
	},{
		name: 'Estiamte reviewed words',
		data: data["review_estimate"],
		stack: 'review',
		color: '#00FF00'
	},{
		name: 'Total issues',
		data: data["total_issues"],
		stack: 'issues',
		color: '#FF6600'
*/
  }]

	chart_values['series'] = chart_values['series'].concat(series);
	chart_values['xAxis']["plotLines"] = get_deadlines(data);
	new Highcharts.Chart(chart_values)
}


