--- Инам ошибок сервисов.
--

local services_error_type = {
  -- Ошибка валидации данных через модель
  VALIDATION_ERROR = 'validation_error',
  -- Ошибка хранилища
  STORAGE_ERROR = 'storage_error',
  -- Внутренняя ошибка при валидации данных из хранилища
  INTERNAL_VALIDATION_ERROR = 'internal_validation_error',
  -- Недостаточно средств для денежной операции (штатная ситуация, не сбой)
  INSUFFICIENT_FUNDS = 'insufficient_funds',
}

return services_error_type
