//1.高阶函数
const filteer = (predicate, xs) => xs.filter(predicate)

const is = (type) => (x) => Object(x) instanceof type

const results = filteer(is(Number), [0, '1', 2, null]) 

//console.log(results)


const sum = (a,c,b) => a+b+c
const arity = sum.length
//console.log(arity)

//2.偏函数
const partical = (f,...args) =>
   (...moreArgs) => 
     f(...args,...moreArgs)

 const add3 = (a,b,c) => a+b+c 

 const fivePlus = partical(add3,2,3)
 //add3(2,3,4),柯里化通过偏函数实现
 const result = fivePlus(4)
 //console.log(result)
 //通过Function.prototype.bind实现偏函数
 const add1More = add3.bind(null,2,3)
 //console.log(add1More(5))

//3.柯里化
const sum1 = (a,b)=>a+b
const curriedSum = (a) => (b) => a+b
curriedSum(2)(3)
const add2 = curriedSum(2)
//curriedSum(2)(10)
const result1 = add2(10)
//console.log(result1)//12


//4.函数组合:从右到左,一个函数的输入为另一个的输出
const compose = (f,g)=> (a) =>f(g(a))
const floorAndToString = compose((val)=>val.toString(),Math.floor)
const result2 = floorAndToString(13.12)
//console.log(result2)

//5.continuation:接收到数据才能执行的结构叫Continuation
const printAsString = (num) => console.log(`Given${num}`)
const addOneAndContinue = (num,cc) => {
	const result4 = num + 1
	cc(result4)
}
//const result5 = addOneAndContinue(2,printAsString)

//console.log(result5)


//6.纯函数:输出仅由输入决定,不产生副作用
const greet = (name)=>console.log(`hello,${name}`)
//greet('world')
//如果函数依赖外部状态,或者函数修改了外部状态都不是纯函数
//1
// window.name = 'Brianne'
// const greet = () => `Hi, ${window.name}`
// greet()
//2
// let greeting
// const greet = (name) => {
//     greeting = `Hi, ${name}`
// }
// greet('Brianne')
// greeting


//7.副作用:如上所说,函数与外部可变状态进行交互则它有副作用
const differentEveryTime = new Date()
//console.log('IO is a side effect')


//8.幂等性:如果一个函数执行多次返回相同的结果,则它是幂等性的
//类似f(f(x)) = f(x)
Math.abs(Math.abs(10))



//9.Point-Free 风格:定义函数时不显式地指出函数所带的参数
const map  = (fn) => (list) => list.map(fn)
const add5 = (a) => (b) => a+b
const incrementAll = (numbers) => map(add5(1))(numbers)
//Point-Free 风格就像平常的赋值,不使用func或者=>
const incrementAll1 = map(add5(1))



//10.谓词(Predicate)
const predicate = (a)=> a>2
const result6 = [1,2,3,4].filter(predicate)
//console.log(result6)



//11.契约:保证函数或者表达式在运行时的行为.违反则抛错
const contract = (input)=>{
	if(typeof input === 'number') return true
	throw new Error('Contract Violated && expected int')
}
const addOne = (num) => contract(num) && num + 1

//console.log(addOne(2))
//console.log(addOne('hello'))






//12.范畴:函子,对象的集合.函子之间的态射(morphism),在编程中,数据类型是对象,函数是态射
//范畴很重要,是monad的基础.态射是可组合的f态射a->b,g态射b->c.g(f(x))和f(g(x))是等价的
//13.常量引用透明
const five = 5
const john = Object.freeze({name:'John',age:30})
const bool = john.age + five === ({name:'John',age:30}).age + 5
//console.log(bool)

//14.函子:一个实现了map函数的对象,map会遍历对象中的每个值并生成新的对象.
//遵守两个准则:一致性,组合性
//在JS 中Array就是典型的函子
const f = x => x+1
const g = x => x*2
// console.log([1,2,3].map(x=>f(g(x))))
// console.log([1,2,3].map(g).map(f))

//14.1Pointed Funtor
Array.of(1)
const Container = function(x){
	this.__value = x
}
Container.of = (x) => new Container(x)
console.log(Container.of(3))
console.log(Container.of(Container.of(3)))
Container.prototype.map = function(f){
	return Container.of(f(this.__value))
}
const composor = (h,k) => x => h(k(x))
const r1 = Container.of(3).map(composor(x=>x*3,x=>x+2))
// console.log(r1)
// console.log(Container.of('Hello World').map(s=>s.toUpperCase()))
//15.引用透明性:一个表达式能被它的值替代而不改变程序的行为称为引用透明
//匿名函数被视为一个值
// (function(a){
// 	return a + 1
// })
// (a) => a+1
//16.匿名函数通常作为高阶函数的参数
const result8 = [1,2].map((a) => a + 1)
// console.log(result8)
//可以把lambda(高阶函数)赋值为一个变量
//const add9 = (a) => a + 1

//17.惰性求值(lazy evaluation)按需求值机制,只有当需要计算所得值才会计算
const rand = function *(){
	while(true)
	{
		yield Math.random()
	}
}
const randIter = rand()
// console.log(randIter)
randIter.next()
// console.log(randIter.next())


//18.Monoid 一个对象拥有一个函数用来连接相同类型的对象.这个函数就是Monaid.加法就是一个
//Monoid必须有一个identity,就是对象和这个identity通过Monoid结合之后不会改变对象的值
//1+0就是很好的例子
//同时需要满足自由结合律,例如加法结合律
//console.log([1,2].concat([3,4]))



//19.Monad:拥有of和chain函数的对象.chain很像map,除了用来铺平嵌套的数据
// Array.prototype.chain = function(f){
// 	return this.reduce((acc,it)=>acc.concat(f(it)),[])
// }
// const r2 = Array.of('cat,dog','fish,bird').chain(s => s.split(','))
// console.log(r2)


//20.Comonad:拥有extract 与 extend函数的对象,可以赋值并得到对象value,也可以修改value并得到对象的结构体
const CoIdentity = (v) =>({
	val:v,
	extract(){
		return this.val
	},
	extend(f){
		return CoIdentity(f(this))
	}
})
const a = CoIdentity(1).extract()
const b = CoIdentity(1).extend(x => x.extract()+1)
// console.log(a,b)

//21.Applicative Functor:拥有ap函数的对象
Array.prototype.ap = function(xs){
	return this.reduce((acc,f) => acc.concat(xs.map(f)),[])
}
const rr = [(a)=> a+1].ap([1])
console.log(rr)
//想要结合的数组
const arg1 = [1,2]
const arg2 = [5,6]
//以何种方式结合,函数的参数必须柯里化
const add = (x)=>(y) => x+y
const partiallyAppliedAdds = [add].ap(arg1)
const r3 =console.log(partiallyAppliedAdds.ap(arg2))


//22.Option
// 定义
const Some = (v) => ({
  val: v,
  map (f) {
    return Some(f(this.val))
  },
  chain (f) {
    return f(this.val)
  }
})

const None = () => ({
  map (f) {
    return this
  },
  chain (f) {
    return this
  }
})

// maybeProp :: (String, {a}) -> Option a
const maybeProp = (key, obj) => typeof obj[key] === 'undefined' ? None() : Some(obj[key])

// getItem :: Cart -> Option CartItem
const getItem = (cart) => maybeProp('item', cart)

// getPrice :: Item -> Option Number
const getPrice = (item) => maybeProp('price', item)

// getNestedPrice :: cart -> Option a
const getNestedPrice = (cart) => getItem(cart).chain(getPrice)

getNestedPrice({}) // None()
getNestedPrice({item: {foo: 1}}) // None()
getNestedPrice({item: {price: 9.99}}) // Some(9.99)
//Option还叫maybe,Some也叫Just,None称为Nothing

//23.Maybe
const Maybe = function(x){
	this.__value = x
}
Maybe.of = (x) => new Maybe(x)

Maybe.prototype.isNothing = function(){
	return this.__value === null || this.__value === undefined
}

Maybe.prototype.map = function(f){
	return this.isNothing() ? Maybe.of(null) : Maybe.of(f(this))
}























