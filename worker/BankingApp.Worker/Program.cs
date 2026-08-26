using BankingApp.Worker;
using BankingApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Infrastructure;
using BankingApp.Application.Interfaces;
using BankingApp.Infrastructure.Services;
using Microsoft.Extensions.Options;

var builder = Host.CreateApplicationBuilder(args);
QuestPDF.Settings.License = LicenseType.Community;
builder.Services.AddOptions<RabbitMqConsumerOptions>()
    .Bind(builder.Configuration.GetSection(RabbitMqConsumerOptions.SectionName))
    .ValidateOnStart();
builder.Services.AddSingleton<IValidateOptions<RabbitMqConsumerOptions>,
    RabbitMqConsumerOptionsValidator>();
builder.Services.Configure<AuditArchiveOptions>(
    builder.Configuration.GetSection(AuditArchiveOptions.SectionName));
builder.Services.Configure<ReportGenerationOptions>(builder.Configuration.GetSection(ReportGenerationOptions.SectionName));
builder.Services.Configure<NotificationOptions>(builder.Configuration.GetSection(NotificationOptions.SectionName));
builder.Services.AddDbContext<BankingAppDbContext>(options => options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<INotificationWriter, NotificationWriter>();
builder.Services.AddScoped<OverdueNotificationScanner>();
builder.Services.AddSingleton<IAuditArchiveWriter, JsonLineAuditArchiveWriter>();
builder.Services.AddSingleton<AuditArchiveMessageHandler>();
builder.Services.AddSingleton<IReportPdfGenerator, QuestPdfReportGenerator>();
builder.Services.AddScoped<ReportGenerationHandler>();
builder.Services.AddHostedService<Worker>();
builder.Services.AddHostedService<ReportGenerationWorker>();
builder.Services.AddHostedService<OverdueNotificationWorker>();

var host = builder.Build();
host.Run();
