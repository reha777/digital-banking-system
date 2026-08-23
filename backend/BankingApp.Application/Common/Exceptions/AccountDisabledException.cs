namespace BankingApp.Application.Common.Exceptions;

public sealed class AccountDisabledException()
    : Exception("Your account is no longer active. Please contact support.");
