using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrEmpty(connectionString))
{
    throw new InvalidOperationException("Database connection string 'DefaultConnection' is not configured. Please set it via environment variable 'ConnectionStrings__DefaultConnection'.");
}

app.MapGet("/", () => "SecureWebApp is running!");

app.MapGet("/health", () => 
{
    var healthStatus = new 
    {
        Status = "Healthy",
        Timestamp = DateTime.UtcNow,
        Version = "1.0.0"
    };
    return Results.Json(healthStatus, new JsonSerializerOptions { WriteIndented = true });
});

app.MapGet("/api/data", () =>
{
    var data = new[]
    {
        new { Id = 1, Name = "Item 1", Value = 100 },
        new { Id = 2, Name = "Item 2", Value = 200 },
        new { Id = 3, Name = "Item 3", Value = 300 }
    };
    return Results.Json(data);
});

app.Run();
