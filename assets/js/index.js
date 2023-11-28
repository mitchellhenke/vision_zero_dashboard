import Chart from 'chart.js/auto'

(async function() {
  const response = await fetch("/data/vision_zero/summary/ytd_summary.json");
  const data = await response.json();
  const years = Object.keys(data);
  const fatalities = years.map(year => data[year].total_fatalities)
  const severe_injuries = years.map(year => data[year].total_severe_injuries)
  const pedestrian_fatalities = years.map(year => data[year].pedestrian_fatalities)
  const pedestrian_severe_injuries = years.map(year => data[year].pedestrian_severe_injuries)

   new Chart(
    document.getElementById('fatalities-chart'),
    {
      type: 'line',
      options: {
        animation: false,
        backgroundColor: 'rgb(22, 46, 81)',
        borderColor: 'rgb(22, 46, 81)',
        pointBackgroundColor: 'rgb(22, 46, 81)',
        pointBorderColor: 'rgb(22, 46, 81)',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Year'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Total Fatalities'
            }
          }
        }
      },
      data: {
        labels: years,
        datasets: [
          {
            data: fatalities,
          }
        ]
      }
    }
  );
   new Chart(
    document.getElementById('serious-injuries-chart'),
    {
      type: 'line',
      options: {
        animation: false,
        backgroundColor: 'rgb(181, 9, 9)',
        borderColor: 'rgb(181, 9, 9)',
        pointBackgroundColor: 'rgb(181, 9, 9)',
        pointBorderColor: 'rgb(181, 9, 9)',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Year'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Total Serious Injuries'
            }
          }
        }
      },
      data: {
        labels: years,
        datasets: [
          {
            data: severe_injuries,
          }
        ]
      }
    }
  );

   new Chart(
    document.getElementById('ped-fatalities-chart'),
    {
      type: 'line',
      options: {
        animation: false,
        backgroundColor: 'rgb(22, 46, 81)',
        borderColor: 'rgb(22, 46, 81)',
        pointBackgroundColor: 'rgb(22, 46, 81)',
        pointBorderColor: 'rgb(22, 46, 81)',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Year'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Pedestrian Fatalities'
            }
          }
        }
      },
      data: {
        labels: years,
        datasets: [
          {
            data: fatalities,
          }
        ]
      }
    }
  );
   new Chart(
    document.getElementById('ped-serious-injuries-chart'),
    {
      type: 'line',
      options: {
        animation: false,
        backgroundColor: 'rgb(181, 9, 9)',
        borderColor: 'rgb(181, 9, 9)',
        pointBackgroundColor: 'rgb(181, 9, 9)',
        pointBorderColor: 'rgb(181, 9, 9)',
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            enabled: true
          },
        },
        scales: {
          x: {
            title: {
              display: true,
              text: 'Year'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Pedestrian Serious Injuries'
            }
          }
        }
      },
      data: {
        labels: years,
        datasets: [
          {
            data: severe_injuries,
          }
        ]
      }
    }
  );
})();
