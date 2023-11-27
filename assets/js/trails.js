import Chart from 'chart.js/auto'

(async function() {
  const response = await fetch("/data/trails/monthly.json");
  const data = await response.json();
  const trail_names = data.trail_names;
  const datasets = trail_names.map(name => ({
    label: name,
    data: data.data.filter(row => row.name == name).map((row) => {
      const [year, month, day] = row.date.split('-');
      const date =  Date.parse(row.date + 'T00:00:00.000');
      return {
        x: `${year}-${month}`,
        y: row.count,
        date: date,
      }
    }).sort((a,b) => a.date - b.date)
  }))

  new Chart(
    document.getElementById('monthly-chart'),
    {
      type: 'line',
      options: {
        animation: false,
        plugins: {
          tooltip: {
            enabled: true
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Month'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Trail Count'
            }
          }
        }
      },
      data: {
        datasets: datasets
      }
    }
  );
})();
