using BankingApp.Api.Controllers;
using BankingApp.Api.Middleware;
using BankingApp.Application.Common.Exceptions;
using BankingApp.Application.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc.Routing;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace BankingApp.Infrastructure.Tests;

public class TransactionLifecycleHardeningTests
{
    [Fact]
    public void Generic_transaction_crud_routes_are_not_exposed()
    {
        var actions = typeof(TransactionsController).GetMethods()
            .Where(method => method.DeclaringType == typeof(TransactionsController))
            .SelectMany(method => method.GetCustomAttributes(true)
                .OfType<HttpMethodAttribute>()
                .Select(attribute => (method.Name, attribute.HttpMethods, attribute.Template)))
            .ToList();

        Assert.DoesNotContain(actions, action =>
            action.HttpMethods.Contains("POST") && string.IsNullOrEmpty(action.Template));
        Assert.DoesNotContain(actions, action => action.HttpMethods.Contains("PUT"));
        Assert.DoesNotContain(actions, action => action.HttpMethods.Contains("DELETE"));
    }

    [Fact]
    public void Generic_transaction_write_contracts_do_not_exist()
    {
        var applicationAssembly = typeof(ITransactionService).Assembly;

        Assert.Null(applicationAssembly.GetType(
            "BankingApp.Application.Transactions.TransactionCreateRequest"));
        Assert.Null(applicationAssembly.GetType(
            "BankingApp.Application.Transactions.TransactionUpdateRequest"));
        Assert.DoesNotContain(typeof(ITransactionService).GetMethods(), method =>
            method.Name is "CreateAsync" or "UpdateAsync" or "DeleteAsync");
    }

    [Fact]
    public async Task Rejection_business_validation_is_returned_as_bad_request()
    {
        var context = new DefaultHttpContext();
        context.Response.Body = new MemoryStream();
        var middleware = new ExceptionHandlingMiddleware(
            _ => throw new BusinessException("Razlog odbijanja transakcije je obavezan."),
            NullLogger<ExceptionHandlingMiddleware>.Instance);

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status400BadRequest, context.Response.StatusCode);
    }
}
