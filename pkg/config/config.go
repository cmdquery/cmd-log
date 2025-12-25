package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Batch    BatchConfig    `mapstructure:"batch"`
	RateLimit RateLimitConfig `mapstructure:"ratelimit"`
	Auth     AuthConfig     `mapstructure:"auth"`
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Port         int           `mapstructure:"port"`
	Host         string        `mapstructure:"host"`
	ReadTimeout  time.Duration `mapstructure:"read_timeout"`
	WriteTimeout time.Duration `mapstructure:"write_timeout"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	DBName   string `mapstructure:"dbname"`
	SSLMode  string `mapstructure:"sslmode"`
}

// BatchConfig holds batch processing configuration
type BatchConfig struct {
	Size         int           `mapstructure:"size"`
	FlushInterval time.Duration `mapstructure:"flush_interval"`
}

// RateLimitConfig holds rate limiting configuration
type RateLimitConfig struct {
	Enabled    bool `mapstructure:"enabled"`
	DefaultRPS int  `mapstructure:"default_rps"`
	Burst      int  `mapstructure:"burst"`
}

// AuthConfig holds authentication configuration
type AuthConfig struct {
	APIKeys     []string `mapstructure:"api_keys"`
	AdminAPIKeys []string `mapstructure:"admin_api_keys"`
}

// Load reads configuration from environment variables and config files
func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	
	// Set defaults
	setDefaults()
	
	// Read from environment variables
	viper.SetEnvPrefix("LOG_INGESTION")
	viper.AutomaticEnv()
	
	// Bind environment variables
	bindEnvVars()
	
	// Try to read config file (optional)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
	}
	
	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("error unmarshaling config: %w", err)
	}
	
	return &config, nil
}

func setDefaults() {
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.read_timeout", "10s")
	viper.SetDefault("server.write_timeout", "10s")
	
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.user", "postgres")
	viper.SetDefault("database.password", "postgres")
	viper.SetDefault("database.dbname", "logs")
	viper.SetDefault("database.sslmode", "disable")
	
	viper.SetDefault("batch.size", 1000)
	viper.SetDefault("batch.flush_interval", "5s")
	
	viper.SetDefault("ratelimit.enabled", true)
	viper.SetDefault("ratelimit.default_rps", 100)
	viper.SetDefault("ratelimit.burst", 200)
}

func bindEnvVars() {
	viper.BindEnv("server.port", "LOG_INGESTION_SERVER_PORT")
	viper.BindEnv("server.host", "LOG_INGESTION_SERVER_HOST")
	viper.BindEnv("database.host", "LOG_INGESTION_DB_HOST")
	viper.BindEnv("database.port", "LOG_INGESTION_DB_PORT")
	viper.BindEnv("database.user", "LOG_INGESTION_DB_USER")
	viper.BindEnv("database.password", "LOG_INGESTION_DB_PASSWORD")
	viper.BindEnv("database.dbname", "LOG_INGESTION_DB_NAME")
	viper.BindEnv("database.sslmode", "LOG_INGESTION_DB_SSLMODE")
	viper.BindEnv("batch.size", "LOG_INGESTION_BATCH_SIZE")
	viper.BindEnv("batch.flush_interval", "LOG_INGESTION_BATCH_FLUSH_INTERVAL")
	viper.BindEnv("ratelimit.enabled", "LOG_INGESTION_RATELIMIT_ENABLED")
	viper.BindEnv("ratelimit.default_rps", "LOG_INGESTION_RATELIMIT_DEFAULT_RPS")
	viper.BindEnv("ratelimit.burst", "LOG_INGESTION_RATELIMIT_BURST")
	
	// API keys from environment (comma-separated)
	if apiKeys := os.Getenv("LOG_INGESTION_API_KEYS"); apiKeys != "" {
		keys := strings.Split(apiKeys, ",")
		var trimmedKeys []string
		for _, key := range keys {
			if trimmed := strings.TrimSpace(key); trimmed != "" {
				trimmedKeys = append(trimmedKeys, trimmed)
			}
		}
		viper.Set("auth.api_keys", trimmedKeys)
	}
	
	// Admin API keys from environment (comma-separated)
	if adminKeys := os.Getenv("LOG_INGESTION_ADMIN_API_KEYS"); adminKeys != "" {
		keys := strings.Split(adminKeys, ",")
		var trimmedKeys []string
		for _, key := range keys {
			if trimmed := strings.TrimSpace(key); trimmed != "" {
				trimmedKeys = append(trimmedKeys, trimmed)
			}
		}
		viper.Set("auth.admin_api_keys", trimmedKeys)
	}
}

