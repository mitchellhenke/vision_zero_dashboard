import Chart from 'chart.js/auto'

(async function() {
  const response = await fetch("/data/summary/ytd_summary.json");
  const data = await response.json();
  const years = Object.keys(data);
  const fatalities = years.map(year => data[year].total_fatalities)
  const severe_injuries = years.map(year => data[year].total_severe_injuries)

   new Chart(
    document.getElementById('chart'),
    {
      type: 'line',
      options: {
        animation: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: false
          }
        }
      },
      data: {
        labels: years,
        datasets: [
          {
            data: fatalities,
          },
          {
            data: severe_injuries,
          }
        ]
      }
    }
  );
})();
