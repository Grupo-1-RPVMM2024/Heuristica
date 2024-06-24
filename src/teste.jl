#Arquivo com as funções para rodar o método e devolver alguns resultados numéricos
include("metodo.jl")
include("dados.jl")
using .Dados
using Statistics, StatsPlots, TickTock, LaTeXStrings

#Função que obtém os dados e roda a heurística
function run(; n=199,opt=1,te=10,ts=10,tv=15,maxViag=4,duracaoViag=60, minViagens=[rand(2:3) for i=1:n], TUltViag=[0. for i=1:n])
    #Obtendo os dados das viagens
    viagens=dadosViagens(opt,duracaoViag); m=length(viagens);
    #Obtendo as informações dos operadores
    operadores=dadosOperadores(minViagens)
    #Resolvendo o problema e retornando o vetor de viagens com o campo indOp preenchido e as atualizações feitas nos operadores
    resolveFP(operadores,viagens,te,ts,tv,maxViag,TUltViag)
    #Contando o número de operadores utilizados
    resp=[viagens[i].codOp for i=1:m]; nUtil=length(unique(resp))
    return nUtil, n, viagens, operadores, TUltViag
end

#Funções auxiliares para verificar algumas informações com relação aos operadores
#Retorna as viagens que um operador fez
function checarOpViagens(id,viagens)
    opViags=[]
    for viag in viagens
        if viag.codOp==id
            push!(opViags,viag)
        end
    end
    return opViags
end

#Função para puxar um operador com base no id
function checarOperador(id,operadores)
    for op in operadores
        if op.cod==id
            return op
        end
    end
    return missing
end

#Calcula média, mediana e variancia do numero de viagens realizada pelos operadores em uma determinada viagem
function medidasMoveisViagens(operadores)
    n=length(op); viagens=[]
    for op in operadores
        if op.nViag!=0
            push!(viagens,op.Nviag)
        end
    end
    mediana=median(viagens); media=mean(viagens); variancia=var(viagens)
    return mediana, media, variancia
end

#Função que devolve os resultados
#No caso, um vetor contendo vetores tais que que:
#* A primeira entrada é o código do operador;
#* As seguintes são os id's da viagens que ele irá fazer.
function resultados(operadores,viagens)
    result=[]
    for op in operadores
        viagensOp=checarOpViagens(op.cod,viagens)
        ids=[]; push!(ids,op.cod)
        for v in viagensOp
            push!(ids,v.numViag)
        end
        push!(result,ids)
    end
    return result
end

#Função que devolve a posição de uma determinada viagem no vetor com base no número de identificação dela
function checarPosViag(id,viagens)
    n=length(viagens)
    for i=1:n
        if viagens[i].numViag==id
            return i
        end
    end
    return missing
end

#Verifica quais operadores, dos que já fizeram 4 viagens, teriam tempo para realizar mais uma viagem
#Se ele pode realizar, quais viagens seriam possíveis (id's)?
function checarMaisUmaViag(operadores,viagens,tv,ts,maxViag,TUltViag)
    indOp4Viag=[]; n=length(operadores); m=length(viagens)
    #Filtrando os que fizeram as 4 viagens
    for i=1:n
        if operadores[i].Nviag==maxViag
            push!(indOp4Viag,i)
        end
    end
    #Filtrando os que poderiam fazer uma quinta viagem
    Op5Viag=[]
    #Para cada operador com indice no conjunto indOp4Viag
    for indOp in indOp4Viag
        ind5ViagOp=[] #Conjunto dos id's das viagens que esse operador poderia realizar como sua quinta viagem
        viagOp=checarOpViagens(operadores[indOp].cod,viagens) #Obtendo as viagens que esse operador faria
        ind=checarPosViag(viagOp[4].numViag,viagens) #Pegando o indice da ultima viagem
        t=TUltViag[indOp]; saida=operadores[indOp].HS #Horário de termino da ultima viagem desse operador
        for i=(ind+1):m #Verificando as viagens posteriores a essa ultima viagem
            #Verificamos se ao final da ultima viagem + tempo de deslocamento, o operador ainda estaria trabalhando ou não
            if (t+tv<=saida-ts) && (t+tv<=viagens[i].HP) && (viagens[i].HT<=saida-ts) && (viagens[i].HP<=saida-ts)
                push!(ind5ViagOp,i)
            end        
        end
        if length(ind5ViagOp)>0
            pushfirst!(ind5ViagOp, operadores[indOp].cod)
            push!(Op5Viag,ind5ViagOp)
        end
    end
    return Op5Viag
end

#Roda a função run() um determinado número Ntest de vezes e retorna:
#*A média\mediana\variância de operadores utilizados em todas as instancias
#*O número médio\mediano\variância do numero de operadores que fizeram quatro viagens e poderiam fazer uma quinta
function medidasViagensMult(; tv=15,ts=10,maxViag=4,opt=1, Ntest=100)
    nUtilTot=[] #Vetor do num. de operadores utilizados
    nQuintViag=[] #Vetor do num. de operadores que fizeram 4 viagens e poderiam fazer uma quinta
    for i=1:Ntest
        nUtil,n,viagens,operadores,TUltViag=run(opt=opt, tv=tv)
        push!(nUtilTot,nUtil); push!(nQuintViag, length(checarMaisUmaViag(operadores,viagens,tv,ts,maxViag,TUltViag)))
    end
    medidasUtil=[median(nUtilTot),mean(nUtilTot),var(nUtilTot)]
    medidasQuint=[median(nQuintViag),mean(nQuintViag),var(nQuintViag)]
    return nUtilTot, nQuintViag, medidasUtil, medidasQuint
end

#Função para imprimir o tempo necessário para rodar os testes n vezes com certos dados
function medirTempoRun(; nTest=100, opt=1, tv=15)
    tick()
    for i=1:nTest
       run(opt=opt, tv=tv)
    end
    tock()
end

#Função para rodar e salvar os gráficos de caixa
function plotGraphics(; Ntest=100, opt=1, valores_tv=[10,15,30])
    #Executando os testes e coletando os resultados
    resultUtil=[]; resultQuint=[]; medidasOpUtil=[]; medidasOpQuint=[]
    for i in valores_tv
        nUtilTot, nQuintViag, medidasUtil, medidasQuint=medidasViagensMult(; opt=opt, tv=i, Ntest=Ntest)
        push!(resultUtil, nUtilTot); push!(resultQuint,nQuintViag)
        push!(medidasOpUtil, medidasUtil); push!(medidasOpQuint, medidasQuint)
    end

    #Gráficos 
    #Para os operadores utilizados
    #Definindo os eixos no boxPlot
    labelstv=reshape([L"t_v"*" = "*string(i) for i in valores_tv],1,length(valores_tv))
    labelsy="Num. de operadores"
    labelsx="Duração de "*L"t_v"

    #Plotando para o total de operadores necessários
    p=boxplot(resultUtil, labels=labelstv, xlabel=labelsx, ylabel=labelsy,xticks=[])
    savefig(p,"imagens/Boxplot - Operadores Utilizados - "*string(opt)*".png")
    #Plotando para o número de operadores que teriam tempo de fazer uma quinta viagem
    p=boxplot(resultQuint, labels=labelstv, xlabel=labelsx, ylabel=labelsy, xticks=[])
    savefig(p,"imagens/Boxplot - operadores Quinta Viagem - "*string(opt)*".png")
    return medidasOpUtil, medidasOpQuint
end

#Função para plotar todos os gráficos de caixa de uma vez
#Retorna medidasUtil, um vetor cuja i-esima entrada são listas de vetores contendo:
#mediana, media e variancia para cada valor de t_v, com rel. aos operadores utilizados
#medidasQuint -> Análogo a medidasUtil, mas com informações dos operadores que tem tempo para fazer a quinta viagem
function plotAllGraphics(; Ntest=100, valores_tv=[10,15,30])
    medidasUtil=[]; medidasQuint=[]
    for opt=1:3
        medU,medQ=plotGraphics(Ntest=Ntest, opt=opt,valores_tv=valores_tv)
        push!(medidasUtil,medU); push!(medidasQuint,medQ)
    end
    return medidasUtil, medidasQuint
end

#Só descomentar essa linha de baixo para rodar um teste individual
#nUtil,n,viagens,operadores,TUltViag=run();
