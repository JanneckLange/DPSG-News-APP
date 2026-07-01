module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/?(*.)+(test).ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  verbose: true,
  collectCoverage: true,
  collectCoverageFrom: ['src/**/*.ts'],
  coverageDirectory: 'coverage',
  coveragePathIgnorePatterns: ['/src/index.ts$', '/src/fcm.ts$'],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
