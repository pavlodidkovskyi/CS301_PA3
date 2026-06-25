create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);





create or replace function calculate_order_total(p_order_id int)
returns numeric as $$
declare
    v_total numeric;
begin
    select coalesce(sum(quantity * price), 0)
    into v_total
    from order_items
    where order_id = p_order_id;
    
    return v_total;
end;
$$ language plpgsql;

create or replace procedure create_order(p_customer_id int)
language plpgsql
as $$
begin
    if not exists (select 1 from customers where customer_id = p_customer_id) then
        raise exception 'customer does not exist';
    end if;

    insert into orders (customer_id, total_amount, order_date)
    values (p_customer_id, 0, current_timestamp);
end;
$$;



create or replace procedure add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
language plpgsql
as $$
declare
    v_price numeric(10,2);
    v_stock int;
begin
    if p_quantity <= 0 then
        raise exception 'quantity must be greater than zero';
    end if;

    select price, stock_quantity 
    into v_price, v_stock
    from products 
    where product_id = p_product_id;

    if v_price is null then
        raise exception 'product does not exist';
    end if;

    if v_stock < p_quantity then
        raise exception 'not enough stock quantity';
    end if;

    insert into order_items (order_id, product_id, quantity, price)
    values (p_order_id, p_product_id, p_quantity, v_price);

    update products 
    set stock_quantity = stock_quantity - p_quantity
    where product_id = p_product_id;
end;
$$;

create or replace function tg_update_order_total_func()
returns trigger as $$
declare
    v_order_id int;
begin
    if tg_op = 'delete' then
        v_order_id := old.order_id;
    else
        v_order_id := new.order_id;
    end if;

    update orders
    set total_amount = calculate_order_total(v_order_id)
    where order_id = v_order_id;

    return null;
end;
$$ language plpgsql;

create trigger tg_update_order_total
after insert or update or delete on order_items
for each row
execute function tg_update_order_total_func();

create or replace function tg_log_order_creation_func()
returns trigger as $$
begin
    insert into order_log (order_id, customer_id, action, log_date)
    values (new.order_id, new.customer_id, 'create', current_timestamp);
    return new;
end;
$$ language plpgsql;

create trigger tg_log_order_creation
after insert on orders
for each row
execute function tg_log_order_creation_func();

