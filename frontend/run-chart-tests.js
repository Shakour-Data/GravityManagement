const { exec } = require('child_process');
const fs = require('fs');

console.log('Running chart component tests...');

const testFiles = [
  './components/__tests__/GanttChart.test.tsx',
  './components/__tests__/BurndownChart.test.tsx',
  './components/__tests__/ResourceUtilizationHeatmap.test.tsx'
];

const command = `npx jest ${testFiles.join(' ')} --verbose --json --outputFile=./chart-test-results.json`;

exec(command, { cwd: process.cwd() }, (error, stdout, stderr) => {
  console.log('Test execution completed');

  if (error) {
    console.error('Error running tests:', error);
    fs.writeFileSync('./test-error.log', `Error: ${error.message}\nStdout: ${stdout}\nStderr: ${stderr}`);
    return;
  }

  console.log('Tests completed successfully');
  console.log('Stdout:', stdout);

  if (stderr) {
    console.log('Stderr:', stderr);
  }

  // Read and display the results
  try {
    const results = fs.readFileSync('./chart-test-results.json', 'utf8');
    console.log('Test Results:');
    console.log(results);
  } catch (readError) {
    console.error('Error reading test results:', readError);
  }
});
