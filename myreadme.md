### аналіз запиту 

для аналізу виконав запит отримання товарів з 1 замовлення:
```sql
explain analyze
select
    oi.order_id,
    p.product_name,
    oi.quantity,
    oi.price,
    oi.quantity * oi.price as item_total
from order_items oi
join products p on oi.product_id = p.product_id
where oi.order_id = 1;

результат:
hash join  (cost=27.09..41.32 rows=7 width=274) (actual time=0.039..0.042 rows=2.00 loops=1)


пояснення роботи планувальника:

postgresql виконує цей запит за допомогою операції hash join. спочатку планувальник сканує одну з таблиць і будує в оперативній пам'яті хеш-таблицю за ключем product_id, далі сканує другу таблицю order_items, фільтрує її за умовою order_id = 1 і порівняє знач побудованою хеш-таблицею для швидкого пошуку збігів. це краше для об'єднання невеликих розмірів даних, коли одна з таблиць повністю вміщується в пам'ять