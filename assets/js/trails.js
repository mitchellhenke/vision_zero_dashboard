import Chart from 'chart.js/auto'

(async function() {
  const response = await fetch("/data/trails/monthly.json");
  const data = await response.json();
  const trail_names = data.trail_names;
  const colors = ['#003f5c']
        // backgroundColor: 'rgb(22, 46, 81)',
        // borderColor: 'rgb(22, 46, 81)',
        // pointBackgroundColor: 'rgb(22, 46, 81)',
        // pointBorderColor: 'rgb(22, 46, 81)',


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
              text: 'Date'
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
        datasets: trail_names.map(name => ({
          label: name,
          data: data.data.filter(row => row.name == name).map(row => ({
            x: row.date.substring(0, 7),
            y: row.count,
          }))
        }))
      }
    }
  );
})();
